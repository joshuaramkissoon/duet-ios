//
//  GroupDetailViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum GroupUpdateError: LocalizedError {
    case unauthorized
    case missingGroupId
    case groupNotFound
    case cannotRemoveOwner
    case invalidGroupData
    case removeFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case renameFailed(underlying: Error)
    case updateFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized access. Please log in again."
        case .missingGroupId:
            return "Invalid group identifier."
        case .groupNotFound:
            return "That group does not exist."
        case .cannotRemoveOwner:
            return "You can't remove the group owner."
        case .invalidGroupData:
            return "Oops! Unexpected error occurred. Please try again later."
        case .removeFailed(let underlying),
             .deleteFailed(let underlying),
             .renameFailed(let underlying),
             .updateFailed(let underlying):
            return underlying.localizedDescription
        }
    }
}

@MainActor
class GroupDetailViewModel: ObservableObject {
    @Published var group: DuetGroup
    @Published var members: [User] = []
    @Published var ideas: [GroupIdea] = []
    @Published var inviteLink: URL?
    @Published var isGeneratingLink = false
    @Published var errorMessage: String?
    @Published var isLoadingMembers = false
    @Published var hasLoaded = false

    private let db = Firestore.firestore()
    private let network = NetworkClient.shared
    private var ideasListener: ListenerRegistration?

    init(group: DuetGroup) {
        self.group = group
    }
    
    func loadInitialData() {
        loadMembers()
        startListeningToIdeas()
    }
    
    func getAuthor(authorId: String) -> User? {
        return members.first(where: { $0.id == authorId })
    }

    func loadMembers() {
        let ids = group.members
        guard !ids.isEmpty else { return }
        isLoadingMembers = true
        Task {
            network.getUsers(with: ids) { result in
                DispatchQueue.main.async {
                    self.isLoadingMembers = false
                    switch result {
                    case .success(let users):
                        self.members = users
                        self.hasLoaded = true
                    case .failure(let error):
                        self.hasLoaded = false
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    func updateGroupEmoji(to emoji: String?) async throws {
        guard let groupId = group.id else {
            throw GroupUpdateError.missingGroupId
        }
        
        let docRef = db.collection("groups").document(groupId)
        
        do {
            try await docRef.updateData([
                "emojiIcon": emoji as Any
            ])
            
            // Update local group object
            await MainActor.run {
                group.emojiIcon = emoji
            }
        } catch {
            throw GroupUpdateError.updateFailed(underlying: error)
        }
    }

    @MainActor
    func removeMember(_ memberId: String, from group: DuetGroup) async throws {
        // 1) Make sure we have a valid group ID
        guard let gid = group.id else {
            throw GroupUpdateError.missingGroupId
        }

        if memberId == group.ownerId {
            throw GroupUpdateError.cannotRemoveOwner
        }
        let groupRef = db.collection("groups").document(gid)

        // 2) Verify the group exists
        let snapshot = try await groupRef.getDocument()
        guard snapshot.exists else {
            throw GroupUpdateError.groupNotFound
        }

        // 3) Remove the member
        do {
            try await groupRef.updateData([
                "members": FieldValue.arrayRemove([memberId])
            ])
            
            // Fetch updated group doc to get updated members array
            let updatedSnapshot = try await groupRef.getDocument()
            guard let data = updatedSnapshot.data(),
                  let updatedMemberIds = data["members"] as? [String] else {
                throw GroupUpdateError.invalidGroupData
            }

            // Update local group and members
            self.group.members = updatedMemberIds
            loadMembers()
        } catch {
            throw GroupUpdateError.removeFailed(underlying: error)
        }
    }

    func loadIdeas() {
        // This method is now empty as we use the real-time listener
    }
    
    func leaveGroup(groupId: String) async throws {
        guard !groupId.isEmpty else {
            throw GroupUpdateError.missingGroupId
        }
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            // you might want a more specific error here
            throw GroupUpdateError.unauthorized
        }
        
        let ref = db.collection("groups").document(groupId)
        let snap = try await ref.getDocument()
        guard snap.exists else {
            throw GroupUpdateError.groupNotFound
        }
        
        do {
            try await ref.updateData([
                "members": FieldValue.arrayRemove([currentUserId])
            ])
        } catch {
            throw GroupUpdateError.removeFailed(underlying: error)
        }
    }
    
    @MainActor
    func deleteGroup(groupId: String) async throws {
        // 1) Validate ID
        guard !groupId.isEmpty else {
            throw GroupUpdateError.missingGroupId
        }
        let groupRef = db.collection("groups").document(groupId)

        // 2) Ensure the group exists
        let snapshot = try await groupRef.getDocument()
        guard snapshot.exists else {
            throw GroupUpdateError.groupNotFound
        }

        do {
            // 3) Fetch all docs in the "ideas" subcollection
            let ideasSnap = try await groupRef
                .collection("ideas")
                .getDocuments()

            // 4) Create a write batch
            let batch = db.batch()

            // 5) Queue up deletes for each idea
            for doc in ideasSnap.documents {
                batch.deleteDocument(doc.reference)
            }

            // 6) Finally, queue the group document delete
            batch.deleteDocument(groupRef)

            // 7) Commit the batch
            try await batch.commit()
        } catch {
            throw GroupUpdateError.deleteFailed(underlying: error)
        }
    }
    
    func renameGroup(to newName: String) async throws {
        guard let gid = group.id, !gid.isEmpty else {
            throw GroupUpdateError.missingGroupId
        }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroupUpdateError.invalidGroupData
        }
        
        let ref = db.collection("groups").document(gid)
        let snap = try await ref.getDocument()
        guard snap.exists else {
            throw GroupUpdateError.groupNotFound
        }
        
        do {
            try await ref.updateData(["name": trimmed])
            group.name = trimmed
        } catch {
            throw GroupUpdateError.renameFailed(underlying: error)
        }
    }
    
    @MainActor
    func deleteIdea(ideaId: String, fromGroup groupId: String) async throws {
        guard !groupId.isEmpty else { throw GroupUpdateError.missingGroupId }

        let ideaRef = db.collection("groups")
                        .document(groupId)
                        .collection("ideas")
                        .document(ideaId)

        do {
            try await ideaRef.delete()
            // keep local array in sync
            ideas.removeAll { $0.id == ideaId }
        } catch {
            throw GroupUpdateError.deleteFailed(underlying: error)
        }
    }

    func invite() {
        guard let gid = group.id else { return }
        isGeneratingLink = true
        Task {
            defer { isGeneratingLink = false }
            let deepLink = URL(string: "duet://join?groupId=\(gid)")!
            inviteLink = deepLink
        }
    }

    // MARK: - Ideas Listener
    
    func startListeningToIdeas() {
        guard let groupId = group.id else { 
            print("❌ Cannot start ideas listener: no group ID")
            return 
        }
        
        // Stop any existing listener first
        stopListeningToIdeas()
        
        print("🔄 Starting to listen for group ideas for group: \(groupId)")
        
        ideasListener = db.collection("groups")
            .document(groupId)
            .collection("ideas")
            .order(by: "addedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Ideas listener error for group \(groupId): \(error)")
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ No snapshot received for group ideas")
                    return
                }
                
                print("📄 Received snapshot for group \(groupId) with \(snapshot.documents.count) idea documents")
                print("📄 Snapshot metadata - hasPendingWrites: \(snapshot.metadata.hasPendingWrites), isFromCache: \(snapshot.metadata.isFromCache)")
                
                let fetchedIdeas: [GroupIdea] = snapshot.documents.compactMap { doc in
                    do {
                        let idea = try doc.data(as: GroupIdea.self)
                        print("✅ Parsed idea: \(idea.id) - \(idea.dateIdea.title) - added by: \(idea.addedBy)")
                        return idea
                    } catch {
                        print("❌ Failed to parse group idea from doc \(doc.documentID): \(error)")
                        return nil
                    }
                }
                
                print("🎯 Total parsed ideas for group \(groupId): \(fetchedIdeas.count)")
                
                Task { @MainActor in
                    let oldCount = self?.ideas.count ?? 0
                    self?.ideas = fetchedIdeas
                    self?.hasLoaded = true
                    let newCount = fetchedIdeas.count
                    print("📱 Updated group ideas: \(oldCount) -> \(newCount) ideas")
                    
                    // Force UI update by triggering objectWillChange
                    self?.objectWillChange.send()
                }
            }
        
        print("✅ Ideas listener set up for group: \(groupId)")
    }
    
    func stopListeningToIdeas() {
        ideasListener?.remove()
        ideasListener = nil
        print("🛑 Stopped listening to group ideas")
    }
    
    deinit {
        // Clean up listener directly since deinit is not main actor isolated
        ideasListener?.remove()
        ideasListener = nil
    }
}

// Helper to chunk arrays
fileprivate extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
