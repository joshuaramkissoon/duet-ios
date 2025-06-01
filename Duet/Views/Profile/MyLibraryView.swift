//
//  MyLibraryView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import AVKit

struct MyLibraryView: View {
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @ObservedObject var viewModel: MyLibraryViewModel
    @State private var selectedActivity: DateIdeaResponse?
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    // Default initializer for backwards compatibility
    init() {
        self.viewModel = MyLibraryViewModel()
    }
    
    // Preferred initializer with injected view model
    init(viewModel: MyLibraryViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
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
        .sheet(item: $selectedActivity) { activity in
            NavigationView {
                ActivityDetailLoader(activityId: activity.id)
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
        .onAppear {
            if let userId = authVM.user?.uid {
                viewModel.setAuthorId(userId)
                
                // If we have no data, do regular loading. Otherwise, silent background refresh
                if viewModel.userIdeas.isEmpty {
                    viewModel.loadUserIdeas()
                } else {
                    viewModel.backgroundLoadUserIdeas()
                }
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
                        .fill(Color(.systemBackground))
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.performSearch(with: query)
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
        LazyVStack(spacing: 16) {
            ForEach(viewModel.displayItems, id: \.id) { activity in
                ExploreCard(activity: activity, selectedActivity: $selectedActivity)
                    .onAppear {
                        // Load next page when approaching the end (for user ideas only)
                        if !viewModel.isSearchActive && 
                           activity.id == viewModel.userIdeas.last?.id {
                            viewModel.loadNextUserIdeasPage()
                        }
                    }
            }
            
            // Loading indicator for pagination
            if !viewModel.isSearchActive && viewModel.hasMorePages && viewModel.isLoadingUserIdeas {
                ProgressView()
                    .padding()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Reusable Preset Query Cards Section
struct PresetQueryCardsSection: View {
    let presetQueries: [String]
    let onQueryTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular searches")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(presetQueries, id: \.self) { query in
                    PresetQueryCard(query: query) {
                        onQueryTap(query)
                    }
                }
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
            Image(systemName: "folder")
                .font(.system(size: 48))
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

#Preview {
    NavigationView {
        MyLibraryView()
            .environmentObject(AuthenticationViewModel())
    }
} 