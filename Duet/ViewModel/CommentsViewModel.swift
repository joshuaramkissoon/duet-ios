import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class CommentsViewModel: ObservableObject {
    @Published private(set) var comments: [Comment] = []
    @Published var newCommentText: String = ""

    private let ideaId: String
    private let groupId: String?
    private var listener: ListenerRegistration?

    init(ideaId: String, groupId: String? = nil) {
        self.ideaId = ideaId
        self.groupId = groupId
        startListening()
    }

    deinit { listener?.remove() }

    private func startListening() {
        listener = CommentsService.shared.listenToComments(ideaId: ideaId, groupId: groupId) { [weak self] fetched in
            Task { @MainActor in
                self?.comments = fetched
            }
        }
    }

    var topLevelComments: [Comment] {
        comments.filter { $0.parentCommentId == nil }
    }

    var hasTopLevelComments: Bool {
        !topLevelComments.isEmpty
    }

    var hasAnyComments: Bool {
        !comments.isEmpty
    }

    func replies(for commentId: String) -> [Comment] {
        comments.filter { $0.parentCommentId == commentId }
    }

    func addComment(parentId: String? = nil, completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let content = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        print("Adding comment with content: \(content)")
        CommentsService.shared.addComment(
            ideaId: ideaId,
            groupId: groupId,
            content: content,
            parentCommentId: parentId,
            userId: uid
        ) { [weak self] error in
            Task { @MainActor in
                if error == nil {
                    self?.newCommentText = ""
                    completion?()
                }
            }
        }
    }

    func addComment(withText text: String, parentId: String? = nil, completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        print("Adding comment with content: \(content)")
        CommentsService.shared.addComment(
            ideaId: ideaId,
            groupId: groupId,
            content: content,
            parentCommentId: parentId,
            userId: uid
        ) { error in
            Task { @MainActor in
                if error == nil {
                    completion?()
                }
            }
        }
    }
} 
