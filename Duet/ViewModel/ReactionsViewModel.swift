import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class ReactionsViewModel: ObservableObject {
    @Published private(set) var reactions: [String: [String]] = [:] // emoji: [userIds]

    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    private let ideaId: String
    private let groupId: String?

    init(ideaId: String, groupId: String? = nil) {
        self.ideaId = ideaId
        self.groupId = groupId
        startListening()
    }

    deinit {
        listener?.remove()
    }

    private func startListening() {
        listener = ReactionsService.shared.listenToReactions(ideaId: ideaId, groupId: groupId) { [weak self] map in
            Task { @MainActor in
                self?.reactions = map
            }
        }
    }

    // MARK: - Computed Helpers
    func count(for emoji: String) -> Int {
        reactions[emoji]?.count ?? 0
    }

    func userHasReacted(_ emoji: String, userId: String? = Auth.auth().currentUser?.uid) -> Bool {
        guard let uid = userId else { return false }
        return reactions[emoji]?.contains(uid) ?? false
    }

    // MARK: - Actions
    func toggleReaction(_ emoji: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        ReactionsService.shared.toggleReaction(emoji: emoji, ideaId: ideaId, groupId: groupId, userId: uid) { err in
            if let err { print("❌ toggle reaction error: \(err)") }
        }
    }
} 