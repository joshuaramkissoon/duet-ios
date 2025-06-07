//
//  MyLibraryView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import AVKit

struct MyLibraryView: View {
    // We embed an inner NavigationStack to decouple this view's navigation
    // from the parent stack (Profile -> MyLibrary). This prevents the
    // outer NavigationLink anchor from being destroyed when the list
    // changes – which was causing the entire stack (and any presented
    // sheets) to collapse.
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @EnvironmentObject private var toast: ToastManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MyLibraryViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedTags: Set<String> = []
    @State private var isTagFilterExpanded = false
    @State private var ideaToDelete: DateIdeaResponse?
    @State private var showDeleteConfirmation = false
    @State private var selectedActivity: DateIdeaResponse?
    @State private var showDetailView = false
    
    // Add StateObject for DateIdeaViewModel like ActivityHistoryCard does
    @StateObject private var dateIdeaViewModel: DateIdeaViewModel
    
    // Computed property to get all unique tags from current display items
    // This automatically switches between all ideas and search results based on search state
    private var availableTags: [Tag] {
        let allTags = viewModel.displayItems.flatMap { $0.summary.tags }
        let uniqueTags = Dictionary(grouping: allTags, by: { $0.title })
            .compactMapValues { $0.first }
            .values
        return Array(uniqueTags).sorted { $0.title < $1.title }
    }
    
    // Filtered ideas based on selected tags
    private var filteredIdeas: [DateIdeaResponse] {
        if selectedTags.isEmpty {
            return viewModel.displayItems
        }
        return viewModel.displayItems.filter { idea in
            let ideaTags = Set(idea.summary.tags.map { $0.title })
            return !selectedTags.isDisjoint(with: ideaTags)
        }
    }

    // Default initializer for backwards compatibility
    init() {
        self.viewModel = MyLibraryViewModel()
        self._dateIdeaViewModel = StateObject(wrappedValue: DateIdeaViewModel(toast: ToastManager(), videoUrl: ""))
    }
    
    // Preferred initializer with injected view model
    init(viewModel: MyLibraryViewModel) {
        self.viewModel = viewModel
        self._dateIdeaViewModel = StateObject(wrappedValue: DateIdeaViewModel(toast: ToastManager(), videoUrl: ""))
    }

    var body: some View {
            libraryContent
                .navigationTitle("My Library")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if !viewModel.isSearchFieldVisible {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.showSearchField()
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    isSearchFocused = true
                                }
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(.appPrimary)
                            }
                        }
                    }
                }
                .navigationDestination(isPresented: $showDetailView) {
                    if let selectedActivity = selectedActivity {
                        DateIdeaDetailView(
                            dateIdea: selectedActivity,
                            onImmersiveToggle: {
                                // Do nothing - we don't want immersive mode in library
                            },
                            viewModel: dateIdeaViewModel
                        )
                        .navigationBarBackButtonHidden(false)
                    }
                }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                keyboardHeight = keyboardFrame.cgRectValue.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .onChange(of: viewModel.isSearchActive) { _, isSearchActive in
            // Reset selected tags when search state changes (both starting and stopping search)
            selectedTags.removeAll()
            if isSearchActive {
                isTagFilterExpanded = false // Collapse the filter when starting a search
            }
        }
        .onChange(of: viewModel.query) { _, newQuery in
            // Reset selected tags when search query changes (but not when cleared)
            if !newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedTags.isEmpty {
                selectedTags.removeAll()
            }
        }
        .onAppear {
            if let userId = authVM.user?.uid {
                viewModel.setAuthorId(userId)
                
                // If we have no data, do regular loading. Otherwise, do a simple background refresh like other views
                // viewModel.backgroundLoadUserIdeas()
                if viewModel.userIdeas.isEmpty {
                    viewModel.loadUserIdeas()
                } else {
                    // Simple background refresh without timing restrictions - same as ExploreView approach
                    // viewModel.backgroundLoadUserIdeas()
                }
            }
            
            // Update the dateIdeaViewModel with the correct toast manager from environment
            dateIdeaViewModel.updateToastManager(toast)
        }
        .onChange(of: selectedActivity) { _, newActivity in
            // Update the dateIdeaViewModel when selectedActivity changes
            if let activity = newActivity {
                dateIdeaViewModel.videoUrl = activity.cloudFrontVideoURL
                dateIdeaViewModel.setCurrentDateIdea(activity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ideaVisibilityUpdated)) { notification in
            // Update selectedActivity if its visibility was changed from elsewhere
            if let selectedActivity = selectedActivity,
               let ideaId = notification.userInfo?["ideaId"] as? String,
               let isPublic = notification.userInfo?["isPublic"] as? Bool,
               ideaId == selectedActivity.id {
                
                // Update the selectedActivity with new visibility
                var updatedActivity = selectedActivity
                updatedActivity = DateIdeaResponse(
                    id: updatedActivity.id,
                    summary: updatedActivity.summary,
                    title: updatedActivity.title,
                    description: updatedActivity.description,
                    thumbnail_b64: updatedActivity.thumbnail_b64,
                    thumbnail_url: updatedActivity.thumbnail_url,
                    video_url: updatedActivity.video_url,
                    videoMetadata: updatedActivity.videoMetadata,
                    original_source_url: updatedActivity.original_source_url,
                    user_id: updatedActivity.user_id,
                    user_name: updatedActivity.user_name,
                    created_at: updatedActivity.created_at,
                    isPublic: isPublic
                )
                self.selectedActivity = updatedActivity
                print("🔄 MyLibraryView: Updated selectedActivity visibility for idea \(ideaId): \(isPublic ? "Public" : "Private")")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ideaMetadataUpdated)) { notification in
            // Update selectedActivity if its metadata was changed from elsewhere
            if let selectedActivity = selectedActivity,
               let ideaId = notification.userInfo?["ideaId"] as? String,
               let updatedIdea = notification.userInfo?["updatedIdea"] as? DateIdeaResponse,
               ideaId == selectedActivity.id {
                
                self.selectedActivity = updatedIdea
                print("🔄 MyLibraryView: Updated selectedActivity metadata for idea \(ideaId)")
            }
        }
        .confirmationDialog(
            "Delete Idea",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let ideaToDelete = ideaToDelete {
                    Task {
                        await deleteIdea(ideaToDelete)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                ideaToDelete = nil
            }
        } message: {
            Text("This action cannot be undone. The idea will be permanently deleted.")
        }
    }

    // MARK: - Extracted Content
    @ViewBuilder
    private var libraryContent: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            if viewModel.isLoadingAny && viewModel.displayItems.isEmpty && !viewModel.isSearchFieldVisible {
                if viewModel.isSearchActive {
                    SearchingView()
                } else {
                    LoadingLibraryView()
                }
            }
            else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    viewModel.refresh()
                }
            }
            else {
                mainContent
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Search Section (when visible)
                    if viewModel.isSearchFieldVisible {
                        searchSection
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .id("searchSection")
                    }
                    
                    // Tag Filter Section (always visible when there are ideas)
                    if !viewModel.displayItems.isEmpty && !availableTags.isEmpty {
                        TagFilterView(
                            availableTags: availableTags,
                            selectedTags: $selectedTags,
                            isExpanded: $isTagFilterExpanded,
                            displayItems: viewModel.displayItems
                        )
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Content
                    if viewModel.isLoadingAny && viewModel.displayItems.isEmpty {
                        loadingContent
                    }
                    else if viewModel.isSearchActive && viewModel.hasSearched && viewModel.searchResults.isEmpty {
                        EmptySearchView()
                    }
                    else if !viewModel.isSearchActive && viewModel.userIdeas.isEmpty {
                        EmptyLibraryView()
                    }
                    else {
                        contentItems
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                // Only refresh if keyboard is not visible
                if keyboardHeight == 0 {
                    viewModel.refresh()
                }
            }
            .onChange(of: viewModel.isSearchFieldVisible) { _, isVisible in
                if isVisible {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("searchSection", anchor: .top)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var searchSection: some View {
        VStack(spacing: 16) {
            // Search Field with Cancel
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Search your ideas...", text: $viewModel.query)
                        .focused($isSearchFocused)
                        .disableAutocorrection(true)
                        .submitLabel(.return)
                        .onSubmit {
                            isSearchFocused = false
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isSearchFocused = false
                                }
                                .foregroundColor(.appPrimary)
                            }
                        }
                    
                    if !viewModel.query.isEmpty {
                        Button(action: { viewModel.query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.adaptiveCardBackground)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                )
                
                Button("Cancel") {
                    isSearchFocused = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.hideSearchField()
                    }
                }
                .foregroundColor(.appPrimary)
                .fontWeight(.medium)
            }
            
            // Preset Query Cards (only when not searching)
            if !viewModel.isSearchActive && viewModel.query.isEmpty {
                PresetQueryCardsSection(
                    presetQueries: viewModel.presetQueries,
                    onQueryTap: { query in
                        isSearchFocused = false
                        // Extract text without emoji - strip common emoji patterns
                        let cleanQuery = query
                            .replacingOccurrences(of: "🍷 ", with: "")
                            .replacingOccurrences(of: "🏃‍♂️ ", with: "")
                            .replacingOccurrences(of: "🏠 ", with: "")
                            .replacingOccurrences(of: "✈️ ", with: "")
                            .replacingOccurrences(of: "🎨 ", with: "")
                            .replacingOccurrences(of: "💪 ", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Set the clean query and perform search
                        viewModel.query = cleanQuery
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.performSearch(with: cleanQuery)
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var loadingContent: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                .scaleEffect(1.2)
            
            Text(viewModel.isSearchActive ? "Searching your ideas for \(viewModel.query.lowercased())" : "Loading your ideas")
                .font(.headline)
                .foregroundColor(.appPrimary)
        }
        .padding(.top, 60)
    }
    
    @ViewBuilder
    private var contentItems: some View {
        ReusableMasonryGrid(
            activities: filteredIdeas,
            style: .library,
            onVideoTap: { activity, _ in
                selectedActivity = activity
                showDetailView = true
            },
            onLoadMore: {
                // Load next page when approaching the end (for user ideas only)
                if !viewModel.isSearchActive {
                    viewModel.loadNextUserIdeasPage()
                }
            },
            onDeleteTap: { activity in
                ideaToDelete = activity
                showDeleteConfirmation = true
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        
        // Loading indicator for pagination
        if !viewModel.isSearchActive && viewModel.hasMorePages && viewModel.isLoadingUserIdeas {
            ProgressView()
                .padding()
        }
    }
    
    // MARK: - Delete Functionality
    
    private func deleteIdea(_ activity: DateIdeaResponse) async {
        do {
            let endpoint = NetworkClient.shared.baseUrl + "/ideas/\(activity.id)"
            let _: EmptyResponse = try await NetworkClient.shared.deleteJSON(url: endpoint)
            
            await MainActor.run {
                // Clear the delete state
                ideaToDelete = nil
                
                // Show success feedback
                HapticFeedbacks.success()
                toast.success("Idea deleted successfully")
                print("🗑️ Deleted idea: \(activity.id)")
                
                // Notify other parts of the app that an idea was deleted
                // This will trigger MyLibraryViewModel and other view models to update their local state
                NotificationCenter.default.post(
                    name: .ideaDeleted,
                    object: nil,
                    userInfo: ["ideaId": activity.id]
                )
            }
        } catch {
            await MainActor.run {
                // Clear the delete state even on error
                ideaToDelete = nil
                
                // Show error feedback
                HapticFeedbacks.error()
                toast.error("Failed to delete idea")
                print("❌ Failed to delete idea \(activity.id): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Loading and Empty States
struct LoadingLibraryView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image("duet")
              .resizable()
              .scaledToFit()
              .clipShape(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
              )
              .padding(.horizontal, 40)
              .padding(.top, 20)
            
            Text("Loading your ideas")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.appPrimary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                .scaleEffect(1.5)
                .padding(.top, 16)
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .withAppBackground()
    }
}

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("duet-group")
                .resizable()
                .scaledToFit()
                .padding(.leading, 60)
                .padding(.trailing, 60)
                .foregroundColor(.appPrimary)
            
            Text("No ideas yet")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Your ideas will appear here once you start creating!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

// MARK: - Tag Filter View
struct TagFilterView: View {
    let availableTags: [Tag]
    @Binding var selectedTags: Set<String>
    @Binding var isExpanded: Bool
    let displayItems: [DateIdeaResponse]
    
    private var filteredCount: Int {
        if selectedTags.isEmpty {
            return displayItems.count
        }
        return displayItems.filter { idea in
            let ideaTags = Set(idea.summary.tags.map { $0.title })
            return !selectedTags.isDisjoint(with: ideaTags)
        }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Filter by Tags")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Show filtered count when tags are selected
                if !selectedTags.isEmpty {
                    Text("\(filteredCount) ideas")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.appPrimary.opacity(0.1))
                        )
                }
                
                // Clear All button
                if !selectedTags.isEmpty {
                    Button("Clear") {
                        HapticFeedbacks.soft()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTags.removeAll()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.appPrimary)
                }
                
                // Expand/Collapse button
                Button(action: {
                    HapticFeedbacks.soft()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .padding(.horizontal, 4)
            
            // Tags display
            if isExpanded {
                // Expanded: Show all tags in a flexible grid that prevents truncation
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100, maximum: 200), spacing: 8)
                ], spacing: 8) {
                    ForEach(availableTags, id: \.title) { tag in
                        TagPillButton(
                            tag: tag,
                            isSelected: selectedTags.contains(tag.title),
                            onTap: {
                                HapticFeedbacks.soft()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedTags.contains(tag.title) {
                                        selectedTags.remove(tag.title)
                                    } else {
                                        selectedTags.insert(tag.title)
                                    }
                                }
                            }
                        )
                    }
                }
            } else {
                // Collapsed: Show tags in horizontal scroll with proper bleeding
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableTags.prefix(20), id: \.title) { tag in
                            TagPillButton(
                                tag: tag,
                                isSelected: selectedTags.contains(tag.title),
                                onTap: {
                                    HapticFeedbacks.soft()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedTags.contains(tag.title) {
                                            selectedTags.remove(tag.title)
                                        } else {
                                            selectedTags.insert(tag.title)
                                        }
                                    }
                                }
                            )
                        }
                        
                        // Show more indicator if there are more tags
                        if availableTags.count > 20 {
                            Button(action: {
                                HapticFeedbacks.soft()
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExpanded = true
                                }
                            }) {
                                Text("+\(availableTags.count - 20)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.appPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(Color.appPrimary.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                    .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 16) // Start offset for bleeding effect
                    .padding(.trailing, 16)
                }
                .padding(.leading, -16) // Allow bleeding from leading edge
                .padding(.trailing, -16) // Allow bleeding from trailing edge
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.adaptiveCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.systemGray5), lineWidth: 0.5)
                )
        )
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}

// MARK: - Tag Pill Button
struct TagPillButton: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if UIImage(systemName: tag.icon) != nil {
                    Image(systemName: tag.icon)
                        .font(.caption)
                }
                Text(tag.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 32) // Use minHeight instead of fixed height
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.appPrimary : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .gray)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .frame(height: 36) // Provide enough space for scaling (32 * 1.05 ≈ 34)
    }
}

// MARK: - Response Models

struct EmptyResponse: Codable {
    // Empty struct for endpoints that return no content
}

#Preview {
    NavigationView {
        MyLibraryView()
            .environmentObject(AuthenticationViewModel())
    }
} 
