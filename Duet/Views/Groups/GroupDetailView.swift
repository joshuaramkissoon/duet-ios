//
//  GroupDetailView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import AVKit

struct GroupDetailView: View {
    @EnvironmentObject private var toast: ToastManager
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: GroupDetailViewModel
    @State private var showingShareSheet = false
    @State private var toastState: ToastState?
    @State private var showingRenameAlert = false
    @State private var renameText: String = ""
    @State private var showingEmojiSelection = false
    

    init(group: DuetGroup) {
        _viewModel = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }
    
    init(viewModel: GroupDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    private var isOwner: Bool {
        authVM.user?.uid == viewModel.group.ownerId
    }

    // MARK: - Computed styling
    private var groupColor: Color {
        return getColorForText(viewModel.group.name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    ideasSection
                }
                .padding(.top)
            }
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if isOwner {
                            Button {
                                // preset the text field to current name
                                renameText = viewModel.group.name
                                showingRenameAlert = true
                            } label: {
                                Label("Rename Group", systemImage: "pencil")
                            }
                        }
                        Button(role: .destructive) {
                            isOwner ? deleteGroup() : leaveGroup()
                        } label: {
                            if isOwner {
                                Label("Delete Group", systemImage: "trash")
                            }
                            else {
                                Label("Leave Group", systemImage: "arrowshape.turn.up.left")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .accessibilityLabel("Options")
                    }
                }
            }
            .alert("Rename Group",
                   isPresented: $showingRenameAlert,
                   actions: {
                       TextField("New name", text: $renameText)
                       Button("Rename") {
                           performRename()
                       }
                       Button("Cancel", role: .cancel) { showingRenameAlert = false }
                   },
                   message: {
                       Text("Enter a new name for your group.")
                   }
            )
            .sheet(isPresented: $showingShareSheet) {
                if let link = viewModel.inviteLink {
                    InviteQRView(url: link, group: viewModel.group)
                }
            }
            .onAppear {
                if !viewModel.hasLoaded {
                    viewModel.loadInitialData()
                }
            }
        }
        .withAppBackground()
    }
}

private extension GroupDetailView {
    private func performRename() {
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        Task {
            do {
                try await viewModel.renameGroup(to: newName)
                toast.success("Renamed group to “\(newName)”")
            } catch {
                toast.error(error.localizedDescription)
            }
        }
    }

    private func leaveGroup() {
        guard let id = viewModel.group.id else {
            return
        }
        Task {
            do {
                try await viewModel.leaveGroup(groupId: id)
                toast.success("You left \(viewModel.group.name)")
                dismiss()
            } catch {
                toast.error(error.localizedDescription)
            }
        }
    }
    
    private func deleteGroup() {
        guard let id = viewModel.group.id else {
            return
        }
        Task {
            do {
                try await viewModel.deleteGroup(groupId: id)
                toast.success("Deleted group: \(viewModel.group.name)")
                dismiss()
            } catch {
                toast.error(error.localizedDescription)
            }
        }
    }
}

// MARK: - Subviews

private extension GroupDetailView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                VStack(alignment: .center) {
                    GroupIcon(group: viewModel.group, diam: 80, fontSize: 30)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingEmojiSelection.toggle()
                            }
                        }
                    
                    Text(viewModel.group.name)
                        .multilineTextAlignment(.leading)
                        .font(.title)
                        .bold()
                        .padding(.horizontal)
                }
                Spacer()
            }
            .padding(.bottom)
            
            // Inline emoji picker
            if showingEmojiSelection {
                VStack(spacing: 12) {
                    HStack {
                        Text("Update Group Icon")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Done") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingEmojiSelection = false
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)
                    }
                    .padding(.horizontal)
                    
                    EmojiPickerContent(
                        selectedEmoji: Binding(
                            get: { viewModel.group.emojiIcon },
                            set: { newEmoji in
                                Task {
                                    do {
                                        try await viewModel.updateGroupEmoji(to: newEmoji)
                                        toast.success("Group icon updated")
                                    } catch {
                                        toast.error(error.localizedDescription)
                                    }
                                }
                            }
                        )
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingEmojiSelection = false
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity.combined(with: .scale))
            }
                
            memberScroll
        }
    }

    var inviteButton: some View {
        Button(action: { showingShareSheet = true; viewModel.invite() }) {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.appPrimary.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.appPrimary)
                    )
                
                Text("Invite")
                    .font(.caption).bold()
                    .foregroundColor(.appPrimary)
            }
        }
    }
    
    var memberScroll: some View {
        VStack {
            HStack {
                Text("Members")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.leading)
                Spacer()
            }
                
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Invite button
                    inviteButton
                        .padding(.trailing, 6)
                    
                    Divider().frame(width: 1, height: 70)
                    
                    // Members
                    if viewModel.isLoadingMembers {
                        // Skeleton loading
                        SkeletonLoadingView(count: 3)
                    }
                    else {
                        HStack(spacing: 0) {
                            ForEach(viewModel.members) { member in
                                userInfoView(for: member)
                            }
                        }
                    }
                }
                .padding(.leading, 24)
                .padding(.vertical, 8)
            }
        }
    }
    
    @ViewBuilder
    func userInfoView(for member: User) -> some View {
        let isCurrentUser = member.id == authVM.user?.uid
        let displayName = isCurrentUser ? "You" : member.displayName
        
        VStack(spacing: 4) {
            ProfileImage(user: member, diam: 50)
            Text(displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .contextMenu {
            if member.id != viewModel.group.ownerId {
                let removeName = isCurrentUser ? "yourself" : member.displayName
                Button(role: .destructive) {
                    Task {
                        do {
                            try await viewModel.removeMember(member.id, from: viewModel.group)
                            toast.success("Removed \(removeName) from \(viewModel.group.name)")
                        } catch {
                            toast.error(error.localizedDescription)
                        }
                    }
                } label: {
                    isCurrentUser ?
                        Label("Leave group", systemImage: "arrowshape.turn.up.left")
                    : Label("Remove \(removeName)", systemImage: "trash")
                }
            }
        }
    }

    var ideasSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shared Ideas")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.leading)

            if viewModel.ideas.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)
                        .foregroundColor(.appPrimary)
                    Text("No ideas shared yet")
                        .font(.headline)
                    Text("When you share an idea to this group, it will appear in this list.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.ideas, id: \.id) { idea in
                        let dateIdeaRes = DateIdeaResponse.fromGroupIdea(idea)
                        let author = viewModel.getAuthor(authorId: idea.addedBy)
                        ActivityHistoryCard(activity: dateIdeaRes, showAuthor: true, author: author, sharedAt: idea.addedAt) {
                            await removeIdea(ideaID: idea.id)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    @MainActor
    private func removeIdea(ideaID: String) async {
        guard let id = viewModel.group.id else { return }
        do {
            try await viewModel.deleteIdea(
                ideaId: ideaID,
                fromGroup: id
            )
            toast.success("Idea removed")
        } catch {
            toast.error(error.localizedDescription)
        }
    }

}

final class MockGroupDetailViewModel: GroupDetailViewModel {
    init() {
        super.init(group: DuetGroup(
            id: "mock-group",
            name: "Mock Group with long title multiline",
            ownerId: "owner123",
            members: ["u1", "u2", "u3"]
        ))
        // Inject dummy members
        self.members = [
            User(id: "u1", name: "Alice Smith"),
            User(id: "u2", name: "Bob Johnson"),
            User(id: "u3", name: "Charlie")
        ]
        self.isLoadingMembers = true
        // Inject dummy ideas
        let sampleIdea = DateIdeaResponse(
            id: "idea1",
            summary: DateIdea(
                id: "idea1",
                title: "Stargazing Picnic",
                summary: "Enjoy a cozy picnic under the stars.",
                sales_pitch: "Romantic, memorable, and out of this world!",
                activity: Activity(title: "Outdoor", icon: "sparkles"),
                location: "Hilltop Park",
                season: .summer,
                duration: "2–3 hours",
                cost_level: .medium,
                required_items: ["Blanket", "Snacks", "Binoculars"],
                tags: [Tag(id: "night", title: "Night", icon: "moon.stars")],
                suggested_itinerary: nil
            ),
            title: "Stargazing Picnic",
            description: "",
            thumbnail_b64: "Stargazing with picnic vibes",
            thumbnail_url: "",
            video_url: "",
            original_source_url: nil,
        )
        self.ideas = [sampleIdea.toGroupIdea()]
        self.inviteLink = URL(string: "duet://join?groupId=mock-group")
    }
    
    override func loadMembers() { /* no-op */ }
    override func loadIdeas()   { /* no-op */ }
    override func invite()      { /* no-op */ }
}


#Preview {
    GroupDetailView(viewModel: MockGroupDetailViewModel())
        .environmentObject(ToastManager())
        .environmentObject(AuthenticationViewModel())
}
