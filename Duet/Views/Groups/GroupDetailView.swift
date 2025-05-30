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
    @EnvironmentObject private var processingManager: ProcessingManager
    @EnvironmentObject private var activityVM: ActivityHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: GroupDetailViewModel
    @State private var showingShareSheet = false
    @State private var toastState: ToastState?
    @State private var showingRenameAlert = false
    @State private var renameText: String = ""
    @State private var showingEmojiSelection = false
    @State private var showingURLInput = false
    @State private var showingIdeasSearch = false
    @State private var ideasSearchQuery = ""
    

    init(group: DuetGroup) {
        _viewModel = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }
    
    init(viewModel: GroupDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    private var isOwner: Bool {
        authVM.user?.uid == viewModel.group.ownerId
    }

    // MARK: - Search functionality             
    private var filteredIdeas: [GroupIdea] {
        guard !ideasSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.ideas
        }
        
        let query = ideasSearchQuery.lowercased()
        return viewModel.ideas.filter { idea in
            // Search in title
            if idea.dateIdea.title.lowercased().contains(query) {
                return true
            }
            
            // Search in sales pitch
            if idea.dateIdea.sales_pitch.lowercased().contains(query) {
                return true
            }
            
            // Search in summary
            if idea.dateIdea.summary.lowercased().contains(query) {
                return true
            }
            
            // Search in location
            if idea.dateIdea.location.lowercased().contains(query) {
                return true
            }
            
            // Search in season
            if idea.dateIdea.season.rawValue.lowercased().contains(query) {
                return true
            }
            
            // Search in tags
            if idea.dateIdea.tags.contains(where: { $0.title.lowercased().contains(query) }) {
                return true
            }
            
            return false
        }
    }
    
    private func showIdeasSearch() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingIdeasSearch = true
        }
    }
    
    private func hideIdeasSearch() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingIdeasSearch = false
            ideasSearchQuery = ""
        }
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
                    
                    // Prominent Add Video button (CTA)
                    addVideoCTA
                    
                    // URL Input Section (stylish card)
                    if showingURLInput {
                        urlInputCard
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                    
                    GroupIdeasView(
                        viewModel: viewModel,
                        filteredIdeas: filteredIdeas,
                        showingSearch: showingIdeasSearch,
                        onShowSearch: showIdeasSearch,
                        onHideSearch: hideIdeasSearch,
                        searchQuery: $ideasSearchQuery
                    )
                        .environmentObject(toast)
                        .environmentObject(processingManager)
                }
                .padding(.top)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingURLInput.toggle()
                            }
                        } label: {
                            Label(showingURLInput ? "Hide URL Input" : "Add Video", systemImage: showingURLInput ? "minus.circle" : "plus.circle")
                        }
                        
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
                // Configure the shared processing manager
                processingManager.updateToast(toast)
                
                print("🔄 GroupDetailView appeared for group: \(viewModel.group.id ?? "unknown")")
                
                if !viewModel.hasLoaded {
                    print("📱 Loading initial data for group")
                    viewModel.loadInitialData()
                } else {
                    // If already loaded, just start the ideas listener
                    print("📱 Group already loaded, starting ideas listener")
                    viewModel.startListeningToIdeas()
                }
                
                // Start tracking group processing jobs
                if let groupId = viewModel.group.id {
                    processingManager.startListeningToGroupJobs(groupId: groupId)
                }
            }
            .onDisappear {
                // Only stop processing manager group tracking, not the ideas listener
                // The ideas listener should persist for smooth navigation
                if let groupId = viewModel.group.id {
                    processingManager.stopListeningToGroupJobs(groupId: groupId)
                    print("🛑 GroupDetailView disappeared - stopped processing manager tracking for group: \(groupId)")
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
                        .foregroundColor(.midnightSlateSoft)
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
                    .foregroundColor(.midnightSlateSoft)
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

    // New self-contained card
    private var urlInputCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

            VStack(spacing: 0) {
                HStack {
                    Text("Add Video")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.midnightSlateSoft)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingURLInput = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
                .padding()

                Divider()

                GroupURLInputView(
                    processingManager: processingManager,
                    groupId: viewModel.group.id ?? "",
                    showCardBackground: false
                )
                .padding(.bottom)
            }
        }
        .padding(.horizontal, 12)
    }

    // NEW: Add-video CTA shown when URL input is hidden
    @ViewBuilder
    private var addVideoCTA: some View {
        if !showingURLInput {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingURLInput.toggle()
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("Add Video")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.appPrimary)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
            }
            .padding(.horizontal)
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
            videoMetadata: nil,
            original_source_url: nil,
            user_id: nil,
            user_name: nil,
            created_at: nil
        )
        self.ideas = [sampleIdea.toGroupIdea()]
        self.inviteLink = URL(string: "duet://join?groupId=mock-group")
    }
    
    override func loadMembers() { /* no-op */ }
    override func startListeningToIdeas() { /* no-op */ }
    override func stopListeningToIdeas() { /* no-op */ }
    override func invite() { /* no-op */ }
}


#Preview {
    let toast = ToastManager()
    return GroupDetailView(viewModel: MockGroupDetailViewModel())
        .environmentObject(toast)
        .environmentObject(AuthenticationViewModel())
}
