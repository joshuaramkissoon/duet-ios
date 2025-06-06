//
//  GroupsViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseDynamicLinks
import Combine

struct DuetGroup: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var emojiIcon: String?
    var ownerId: String
    var members: [String]
    
    var initials: String {
        let words = name.split(separator: " ")
        if words.count > 1 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "GP"
    }
}

struct GroupIdea: Identifiable, Codable {
    let id: String
    let dateIdea: DateIdea
    let videoUrl:  String
    let originalSourceUrl: String?
    let thumbnailB64: String?
    let videoMetadata: VideoMetadata?
    let addedBy: String
    let addedAt: Date
    
    /// Returns the CloudFront CDN URL for the video
    var cloudFrontVideoURL: String {
        return URLHelpers.convertToCloudFrontURL(videoUrl)
    }
}

@MainActor
class GroupsViewModel: ObservableObject {
    @Published var groups: [DuetGroup] = []
    @Published var errorMessage: String?
    @Published var selectedGroup: DuetGroup?
    @Published var inviteLink: URL?
    @Published var joinResult: AlertResult?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    init() {
        setupNotificationListeners()
    }
    
    private func setupNotificationListeners() {
        // Listen for user logout - clear groups and stop listening
        NotificationCenter.default.publisher(for: .userLoggedOut)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.clearAllData()
                print("🔄 GroupsViewModel: Cleared groups on user logout")
            }
            .store(in: &cancellables)
        
        // Listen for user login - restart listening for new user
        NotificationCenter.default.publisher(for: .userLoggedIn)
            .sink { [weak self] notification in
                guard let self = self else { return }
                self.refreshForNewUser()
                print("🔄 GroupsViewModel: Restarting listener for new user")
            }
            .store(in: &cancellables)
    }
    
    /// Clears all cached data when user logs out
    private func clearAllData() {
        groups = []
        errorMessage = nil
        selectedGroup = nil
        inviteLink = nil
        joinResult = nil
        stopListening()
    }
    
    /// Restarts listening for a newly logged in user
    private func refreshForNewUser() {
        // Clear previous user's data first
        clearAllData()
        
        // Start listening for the new user's groups
        startListening()
    }

  func startListening() {
    guard let currentUid else { return }
      listener = db.collection("groups")
      .whereField("members", arrayContains: currentUid)
      .addSnapshotListener { snap, err in
        if let err = err {
          self.errorMessage = err.localizedDescription
          return
        }
          self.groups = snap?.documents.compactMap {
              try? $0.data(as: DuetGroup.self)
          } ?? []
          self.groups.sort {
              $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
          }
      }
  }

  func stopListening() {
    listener?.remove()
  }

    func createGroup(named name: String, emoji: String?) async {
      guard let currentUid else { return }
      let doc = db.collection("groups").document()
    let g = DuetGroup(id: doc.documentID,
                  name: name,
                  emojiIcon: emoji,
                  ownerId: currentUid,
                  members: [currentUid])
    do {
      try doc.setData(from: g)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Generates & shortens a Dynamic Link that invites to this group
  func generateInviteLink(for group: DuetGroup) async {
    guard let gid = group.id else { return }
    inviteLink = URL(string: "duet://join?groupId=\(gid)")
  }

  /// Call when user opens a dynamic link with `groupId`
    @MainActor
    func joinGroup(withId groupId: String) async {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        let ref = db.collection("groups").document(groupId)
        do {
            // 1) Check for existence
            let snapshot = try await ref.getDocument()
            guard snapshot.exists else {
                joinResult = .failure(
                    title: "Oops!",
                    message: "This group doesn't exist."
                )
                return
            }
            // Check user not already member
            let members = snapshot.data()?["members"] as? [String] ?? []
            if members.contains(currentUid) {
                let name = snapshot.data()?["name"] as? String ?? "this group"
                joinResult = .failure(
                    title: "🎉 Already a member",
                    message: "You're already a member of \(name)"
                )
                return
            }
            
            // 2) Perform the join
            try await ref.updateData([
                "members": FieldValue.arrayUnion([currentUid])
            ])
            // 3) Read name and report success
            let name = snapshot.data()?["name"] as? String ?? "Group"
            joinResult = .success(
                title: "🎉 Joined \(name)!",
                message: "You're now part of \(name)."
            )
        } catch {
            joinResult = .failure(
                title: "Oops!",
                message: "Something went wrong: \(error.localizedDescription)"
            )
        }
    }

    enum ShareError: LocalizedError {
        case missingGroupId
        case missingUser
        case groupNotFound
        case duplicateIdea
        case writeFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .missingGroupId:
                return "This group has no valid ID."
            case .missingUser:
                return "You must be signed in to share."
            case .groupNotFound:
                return "The group you're trying to share to doesn't exist."
            case .duplicateIdea:
                return "This idea already exists in this group."
            case .writeFailed(let underlying):
                return underlying.localizedDescription
            }
        }
    }

  /// Share a DateIdea into a group
    @MainActor
    func share(_ idea: DateIdeaResponse, to group: DuetGroup) async throws {
        guard let gid = group.id else {
            throw ShareError.missingGroupId
        }
        guard let uid = currentUid else {
            throw ShareError.missingUser
        }
        
        // 2) Check that the group document exists
        let groupRef = db.collection("groups").document(gid)
        let snapshot = try await groupRef.getDocument()
        guard snapshot.exists else {
            throw ShareError.groupNotFound
        }

        let doc = db
            .collection("groups")
            .document(gid)
            .collection("ideas")
            .document(idea.id)
        
        let ideaExists = try await doc.getDocument().exists
        guard !ideaExists else {
            throw ShareError.duplicateIdea
        }

        let record = GroupIdea(
            id: idea.id,
            dateIdea: idea.summary,
            videoUrl: idea.cloudFrontVideoURL,
            originalSourceUrl: idea.original_source_url,
            thumbnailB64: idea.thumbnail_b64,
            videoMetadata: idea.videoMetadata,
            addedBy: uid,
            addedAt: Date()
        )

        do {
            try doc.setData(from: record)
        } catch {
            throw ShareError.writeFailed(underlying: error)
        }
    }
}
