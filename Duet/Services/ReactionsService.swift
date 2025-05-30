import Foundation
import FirebaseFirestore

/// A singleton helper to manage reactions CRUD and listeners
final class ReactionsService {
    static let shared = ReactionsService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Listener

    /// Listen for reaction changes on a given idea. When updated, the handler receives the map [emoji: [userIds]].
    @discardableResult
    func listenToReactions(
        ideaId: String,
        groupId: String? = nil,
        onUpdate: @escaping ([String: [String]]) -> Void
    ) -> ListenerRegistration? {
        let docRef = self.ideaDocRef(ideaId: ideaId, groupId: groupId)
        return docRef.addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                print("❌ Failed to listen to reactions: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            let reactions = data["reactions"] as? [String: [String]] ?? [:]
            onUpdate(reactions)
        }
    }

    // MARK: - Toggle Reaction

    /// Toggles the current userId for a given emoji (adds if absent, removes if present)
    func toggleReaction(
        emoji: String,
        ideaId: String,
        groupId: String? = nil,
        userId: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let docRef = ideaDocRef(ideaId: ideaId, groupId: groupId)
        
        // First ensure the document exists, then update reactions
        docRef.getDocument { snapshot, error in
            if let error = error {
                completion?(error)
                return
            }
            
            // Get current reactions or empty dict if document doesn't exist
            let currentReactions = snapshot?.data()?["reactions"] as? [String: [String]] ?? [:]
            let usersForEmoji = currentReactions[emoji] ?? []
            let hasReacted = usersForEmoji.contains(userId)
            
            // Calculate new reactions map
            var newReactions = currentReactions
            if hasReacted {
                // Remove user from emoji array
                newReactions[emoji] = usersForEmoji.filter { $0 != userId }
                // Remove empty arrays completely
                if newReactions[emoji]?.isEmpty == true {
                    newReactions.removeValue(forKey: emoji)
                }
            } else {
                // Add user to emoji array
                newReactions[emoji] = usersForEmoji + [userId]
            }
            
            // Use updateData if document exists, setData with merge if it doesn't
            if snapshot?.exists == true {
                // Document exists, use updateData to properly handle deletions
                docRef.updateData([
                    "reactions": newReactions
                ]) { err in
                    if let err = err {
                        print("❌ Reaction update failed: \(err)")
                    }
                    completion?(err)
                }
            } else {
                // Document doesn't exist, create it with setData merge
                docRef.setData([
                    "reactions": newReactions
                ], merge: true) { err in
                    if let err = err {
                        print("❌ Reaction creation failed: \(err)")
                    }
                    completion?(err)
                }
            }
        }
    }

    // Helper to produce idea doc reference according to context
    private func ideaDocRef(ideaId: String, groupId: String?) -> DocumentReference {
        if let gid = groupId {
            return db.collection("groups").document(gid).collection("ideas").document(ideaId)
        } else {
            return db.collection("ideas").document(ideaId)
        }
    }
} 