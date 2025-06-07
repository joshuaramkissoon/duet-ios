//
//  VideoCacheManager.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import Foundation
import SwiftUI
import AVKit
import CryptoKit

// 1) Simple VideoCacheManager
class VideoCacheManager {
    static let shared = VideoCacheManager()
    private init() {}

    // Returns a file URL under Caches keyed by a hash of the remote URL
    private func localFileURL(for remoteURL: URL) -> URL {
        let filename = remoteURL.absoluteString
                           .addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let caches = FileManager.default.urls(
                         for: .cachesDirectory, in: .userDomainMask
                     )[0]
        return caches.appendingPathComponent(filename).appendingPathExtension("mp4")
    }

    /// Download if needed, then call completion with a URL you can feed to AVPlayer
    func url(for remoteURL: URL, completion: @escaping (URL) -> Void) {
        let localURL = self.localFileURL(for: remoteURL)

        // If already downloaded, return immediately
        if FileManager.default.fileExists(atPath: localURL.path) {
            return completion(localURL)
        }

        // Otherwise download into the localURL
        let task = URLSession.shared.downloadTask(with: remoteURL) { tempURL, resp, err in
            guard let temp = tempURL, err == nil else { return }
            do {
                try FileManager.default.moveItem(at: temp, to: localURL)
                DispatchQueue.main.async {
                    completion(localURL)
                }
            } catch {
                print("🛑 VideoCacheManager download/move error:", error)
            }
        }
        task.resume()
    }
}

/// Resolves a remote mp4 / m3u8 URL to a local file URL, downloading & caching if needed.
/// Disk path: <Caches>/VideoCache/<hash>.mp4
actor VideoCache {
    static let shared = VideoCache(maxConcurrent: 2)

    // MARK: - Private state
    private let fm = FileManager.default
    private let mem = NSCache<NSURL, NSURL>()          // in-RAM lookup
    private var inFlight: [URL: Task<URL, Error>] = [:] // coalesce callers

    // simple download gate
    private var active = 0
    private let maxConcurrent: Int

    private init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
    }

    // MARK: - Public API
    func localFile(for remote: URL) async throws -> URL {
        // 0. fast in-memory hit
        if let cached = mem.object(forKey: remote as NSURL) {
            return cached as URL
        }

        // 1. fast on-disk hit
        let local = cachesDir.appendingPathComponent(remote.sha256 + ".mp4")
        if fm.fileExists(atPath: local.path) {
            mem.setObject(local as NSURL, forKey: remote as NSURL)
            return local
        }

        // 2. another download already in progress?
        if let existing = inFlight[remote] {
            return try await existing.value
        }

        // 3. launch a new download task
        let task = Task { () throws -> URL in
            defer { Task { await self.removeInFlight(for: remote) } }

            try await self.acquireGate()
            defer { self.releaseGate() }

            let (tmp, _) = try await VideoCache.session.download(from: remote)
            try self.fm.moveItem(at: tmp, to: local)
            self.mem.setObject(local as NSURL, forKey: remote as NSURL)
            return local
        }

        inFlight[remote] = task
        return try await task.value
    }

    // MARK: - Helpers
    private func removeInFlight(for url: URL) {
        inFlight.removeValue(forKey: url)
    }

    // simple semaphore
    private func acquireGate() async throws {
        while active >= maxConcurrent {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 50_000_000) // 50 ms
        }
        active += 1
    }
    private func releaseGate() { active -= 1 }

    private var cachesDir: URL {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir  = base.appendingPathComponent("VideoCache")
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Custom session: waits-for-connectivity + generous time-outs.
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 30   // seconds
        cfg.timeoutIntervalForResource = 120  // seconds
        cfg.waitsForConnectivity       = true
        return URLSession(configuration: cfg)
    }()
}

// MARK: - Small helper

private extension URL {
    /// Stable file-name per full URL, avoids lastPathComponent collisions.
    var sha256: String {
        let digest = SHA256.hash(data: Data(absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

final class AssetPool {
    static let shared = AssetPool()
    private let cache = NSCache<NSURL, AVURLAsset>()
    private init() { cache.countLimit = 50 }
    
    func asset(for localURL: URL) async throws -> AVURLAsset {
        if let a = cache.object(forKey: localURL as NSURL) {
            return a
        }
    
        let asset = AVURLAsset(url: localURL)
        try await asset.load(.isPlayable)
        cache.setObject(asset, forKey: localURL as NSURL)
        return asset
    }
}

final class SmallPlayerPool {
    static let shared = SmallPlayerPool()
    private var free = [AVQueuePlayer]()
    private init() {}

    func obtain() -> AVQueuePlayer {
        if let p = free.popLast() { return p }
        return AVQueuePlayer()
    }
    
    func recycle(_ p: AVQueuePlayer) {
        p.pause()
        p.removeAllItems()
        if free.count < 6 { free.append(p) }
    }
}

/// Wraps a pooled AVQueuePlayer and keeps its AVPlayerLooper alive.
final class LoopingPlayer {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?   // must be retained
    
    init(player: AVQueuePlayer, item: AVPlayerItem) {
        self.player = player
        player.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: player, templateItem: item)
    }
}
