import Foundation
import FirebaseFirestore

final class CommentsService {
    static let shared = CommentsService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Listener
    @discardableResult
    func listenToComments(
        ideaId: String,
        groupId: String? = nil,
        onUpdate: @escaping ([Comment]) -> Void
    ) -> ListenerRegistration? {
        let collection = commentsCollection(ideaId: ideaId, groupId: groupId)
        return collection
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    print("❌ Failed to listen to comments: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                let comments: [Comment] = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Comment.self)
                }
                
                // Enrich comments with user data
                self.enrichCommentsWithUserData(comments) { enrichedComments in
                    onUpdate(enrichedComments)
                }
            }
    }

    // MARK: - Add Comment
    func addComment(
        ideaId: String,
        groupId: String? = nil,
        content: String,
        parentCommentId: String? = nil,
        userId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let collection = commentsCollection(ideaId: ideaId, groupId: groupId)
        let data: [String: Any] = [
            "userId": userId,
            "content": content,
            "createdAt": Timestamp(date: Date()),
            "parentCommentId": parentCommentId as Any
        ]
        collection.addDocument(data: data) { err in
            if let err { print("❌ Failed to add comment: \(err)") }
            completion?(err)
        }
    }

    // MARK: - User Data Enrichment
    private func enrichCommentsWithUserData(_ comments: [Comment], completion: @escaping ([Comment]) -> Void) {
        let uniqueUserIds = Array(Set(comments.map { $0.userId }))
        
        guard !uniqueUserIds.isEmpty else {
            completion(comments)
            return
        }
        
        NetworkClient.shared.getUsers(with: uniqueUserIds) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
                    let enrichedComments = comments.map { comment in
                        var enrichedComment = comment
                        enrichedComment.author = userDict[comment.userId]
                        return enrichedComment
                    }
                    completion(enrichedComments)
                case .failure(let error):
                    print("❌ Failed to fetch users for comments: \(error)")
                    // Return comments without enrichment if user fetch fails
                    completion(comments)
                }
            }
        }
    }

    // MARK: - Delete Comment
    func deleteComment(
        ideaId: String,
        groupId: String? = nil,
        commentId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let collection = commentsCollection(ideaId: ideaId, groupId: groupId)
        
        // First, get all child comments to delete them too
        collection
            .whereField("parentCommentId", isEqualTo: commentId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Failed to fetch child comments: \(error)")
                    completion?(error)
                    return
                }
                
                // Create a batch to delete parent and all child comments atomically
                let batch = self.db.batch()
                
                // Add parent comment to batch deletion
                let parentDocRef = collection.document(commentId)
                batch.deleteDocument(parentDocRef)
                
                // Add all child comments to batch deletion
                if let documents = snapshot?.documents {
                    for doc in documents {
                        batch.deleteDocument(doc.reference)
                    }
                }
                
                // Execute the batch deletion
                batch.commit { error in
                    if let error = error {
                        print("❌ Failed to delete comment and replies: \(error)")
                    } else {
                        let childCount = snapshot?.documents.count ?? 0
                        if childCount > 0 {
                            print("✅ Deleted comment and \(childCount) replies")
                        } else {
                            print("✅ Deleted comment")
                        }
                    }
                    completion?(error)
                }
            }
    }

    // MARK: - Helpers
    private func commentsCollection(ideaId: String, groupId: String?) -> CollectionReference {
        if let gid = groupId {
            return db.collection("groups").document(gid).collection("ideas").document(ideaId).collection("comments")
        } else {
            return db.collection("ideas").document(ideaId).collection("comments")
        }
    }
} 
