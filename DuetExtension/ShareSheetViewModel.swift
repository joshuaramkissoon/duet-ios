import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct ExtensionGroup: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
}

@MainActor
final class ShareSheetViewModel: ObservableObject {
    @Published var sharedURL: String?
    @Published var groups: [ExtensionGroup] = []
    @Published var selectedGroup: ExtensionGroup?
    @Published var isSubmitting = false
    @Published var error: String?
    @Published var thumbnailURL: URL?
    @Published var thumbnailAspect: CGFloat = 1
    @Published var successMessage: String?

    private let api = ShareExtensionAPI()
    private weak var extContext: NSExtensionContext?

    // MARK: - Bootstrap
    func configure(with context: NSExtensionContext?) {
        self.extContext = context
        extractSharedURL(from: context)
        loadGroups()
    }

    // MARK: - Share Action
    func performShare() {
        guard let url = sharedURL else { return }
        isSubmitting = true
        Task {
            do {
                if let group = selectedGroup {
                    try await api.addVideo(url: url, toGroup: group.id)
                } else {
                    try await api.summarizeVideo(url: url)
                }
                self.successMessage = "Shared to Duet!"
                // Close after short delay to let user see success indicator
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.extContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            } catch {
                self.error = error.localizedDescription
                self.isSubmitting = false
            }
        }
    }

    // MARK: - Helpers
    private func extractSharedURL(from ctx: NSExtensionContext?) {
        guard let item = ctx?.inputItems.first as? NSExtensionItem else { return }
        let providers = item.attachments ?? []

        // 1) direct URL
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                Task { @MainActor in
                    self.sharedURL = (item as? URL)?.absoluteString
                    if let str = self.sharedURL {
                        self.fetchThumbnail(for: str)
                    }
                }
            }
            return
        }

        // 2) any text with link (handles TikTok)
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                Task { @MainActor in
                    if let str = item as? String {
                        self.sharedURL = Self.firstLink(in: str)
                        if let s = self.sharedURL { self.fetchThumbnail(for: s) }
                    }
                }
            }
        }
    }

    private static func firstLink(in text: String) -> String? {
        let pattern = #"https?://[^\s]+"#
        return text.range(of: pattern, options: .regularExpression).map { String(text[$0]) }
    }

    private func loadGroups() {
        guard SharedUserManager.shared.currentUserId != nil else { 
            print("❌ No user ID found, skipping group loading")
            return 
        }
        
        Task {
            do {
                print("🔄 Loading groups from backend...")
                let fetchedGroups = try await api.getUserGroups()
                await MainActor.run {
                    self.groups = fetchedGroups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    print("✅ Loaded \(self.groups.count) groups successfully")
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    print("❌ Failed to load groups: \(error)")
                }
            }
        }
    }

    // MARK: - Thumbnail fetch
    private func fetchThumbnail(for urlString: String) {
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let endpoint = "https://duet-backend-490xp.kinsta.app/thumbnail?url=" + encoded
        guard let reqUrl = URL(string: endpoint) else { return }
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: reqUrl)
                guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else { return }
                struct ThumbResp: Decodable {
                    let thumbnail_url: String
                    let ratio_width: Double?
                    let ratio_height: Double?
                }
                let decoded = try JSONDecoder().decode(ThumbResp.self, from: data)
                let aspect: CGFloat
                if let w = decoded.ratio_width, let h = decoded.ratio_height, w > 0 {
                    aspect = CGFloat(w / h)
                } else {
                    aspect = 1
                }
                await MainActor.run {
                    self.thumbnailURL = URL(string: decoded.thumbnail_url)
                    self.thumbnailAspect = aspect
                }
            } catch {
                // ignore errors silently
            }
        }
    }
} 
