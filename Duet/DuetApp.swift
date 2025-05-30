//
//  DuetApp.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI
import Firebase
import AVFoundation

@main
struct DuetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthenticationViewModel()
    @StateObject private var groupsVM = GroupsViewModel()
    @StateObject private var toastManager = ToastManager()
    @StateObject private var dateIdeaVM = DateIdeaViewModel(toast: ToastManager())
    @StateObject private var activityVM = ActivityHistoryViewModel()
    @StateObject private var exploreVM = ExploreViewModel()
    @StateObject private var processingManager = ProcessingManager(toast: ToastManager())

    init() {
        FirebaseApp.configure()
        configureAudioSession()
        
        // Clean up expired user cache entries on app start
        UserCache.shared.cleanupExpired()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ AVAudioSession error: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                AuthenticationView()
                    .environmentObject(authVM)
                    .environmentObject(groupsVM)
                    .environmentObject(toastManager)
                    .environmentObject(dateIdeaVM)
                    .environmentObject(activityVM)
                    .environmentObject(exploreVM)
                    .environmentObject(processingManager)
                    .onOpenURL(perform: handleInviteURL(_:))
                    .onAppear {
                        // Configure ProcessingManager with proper references
                        processingManager.updateToast(toastManager)
                    }
                
                if let result = groupsVM.joinResult {
                    ResultAlertView(result: result) {
                        groupsVM.joinResult = nil
                    }
                    .zIndex(1)
                }
            }
            .withAppTheme()
        }
    }
    
    private func handleInviteURL(_ url: URL) {
        guard url.scheme == "duet" else { return }
        
        if url.host == "join" {
            // Handle group invites
            guard let gid = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                              .queryItems?
                              .first(where: { $0.name == "groupId" })?
                              .value
            else { return }
            Task {
              await groupsVM.joinGroup(withId: gid)
            }
        } else if url.host == "share" {
            handleSharedUrl(from: url)
        }
    }
    
    private func handleSharedUrl(from url: URL) {
        // Extract videoUrl from URL
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let videoUrl = urlComponents.queryItems?.first(where: { $0.name == "videoUrl" })?.value else {
            toastManager.error("No video URL found in share")
            return
        }
        
        // Check authentication
        if authVM.state == .authenticated {
            dateIdeaVM.urlText = videoUrl
            dateIdeaVM.summariseVideo()
        } else {
            toastManager.error("You must be signed in to process shared videos.")
        }
    }
}
