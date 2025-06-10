//
//  DateIdeaDetailView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI
import AVKit
import FirebaseAuth

struct DateIdeaDetailView: View {
    let dateIdea: DateIdeaResponse
    var groupId: String? = nil
    var scrollToComments: Bool = false
    var hideNavigationBar: Bool = false
    var onImmersiveToggle: (() -> Void)? = nil
    
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: DateIdeaViewModel
    @State private var showShareSheet = false
    @State private var isOptionsExpanded = false
    @State private var authorUser: User?
    @State private var isLoadingAuthor = false
    @State private var showingBlockUser = false
    
    private var sectionTitle: String {
        switch currentDateIdeaResponse.summary.content_type {
        case .recipe:
            return "About This Recipe"
        case .travel:
            return "About This Trip"
        case .activity:
            return "About This Activity"
        case .dateIdea, .none:
            return "About This Date"
        }
    }
    
    /// Check if current user can edit this idea (recipes, itineraries, etc.)
    private var canEdit: Bool {
        // Allow editing if it's a group idea (groupId is non-nil) OR current user is the owner
        if groupId != nil {
            return true
        }
        
        guard let currentUserId = authVM.user?.uid,
              let ideaOwnerId = currentDateIdeaResponse.user_id else {
            return false
        }
        
        return currentUserId == ideaOwnerId
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.videoUrl.isEmpty, let url = URL(string: viewModel.videoUrl) {
                        HStack {
                            Spacer()
                            CachedVideoView(
                                remoteURL: url, 
                                thumbnailB64: currentDateIdeaResponse.thumbnail_b64,
                                aspectRatio: currentDateIdeaResponse.videoMetadata?.aspectRatio ?? 9/16,
                                width: UIScreen.main.bounds.width - 100
                            )
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Video Author Attribution
                        if let videoMetadata = currentDateIdeaResponse.videoMetadata,
                           let authorHandle = videoMetadata.author_handle,
                           let authorUrl = videoMetadata.author_url,
                           let platform = videoMetadata.platform,
                           !authorHandle.isEmpty,
                           !authorUrl.isEmpty {
                            VideoAuthorAttribution(
                                authorHandle: authorHandle,
                                authorUrl: authorUrl,
                                originalSourceUrl: currentDateIdeaResponse.original_source_url,
                                platform: platform
                            ) { url in
                                openURL(url)
                            } onSourceTap: { url in
                                openURL(url)
                            }
                            .padding(.horizontal)
                            .padding(.top, -8)
                        }
                    }
                    
                    // Author section (when current user is not the owner) - moved here
                    if let userId = currentDateIdeaResponse.user_id,
                       let currentUserId = authVM.user?.uid,
                       userId != currentUserId {
                        authorSection
                            .padding(.horizontal)
                    }
                    
                    // Operational Controls Section (always shown, adapts based on permissions)
                    OperationalControlsSection(
                        isExpanded: $isOptionsExpanded,
                        dateIdea: currentDateIdeaResponse,
                        groupId: groupId,
                        canEdit: canEdit,
                        viewModel: viewModel,
                        onShareToGroup: {
                            showShareSheet = true
                        },
                        onImproveWithAI: {
                            // TODO: Implement AI chat functionality
                        }
                    )
                    .padding(.horizontal)
                    
                    // Title and basic info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(currentDateIdeaResponse.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        // Tags row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                CategoryPill(text: currentDateIdeaResponse.summary.activity.title,
                                             icon: currentDateIdeaResponse.summary.activity.icon,
                                             color: .appPrimary)
                                .padding(.leading, 6)
                                
                                CategoryPill(text: currentDateIdeaResponse.summary.season.rawValue.capitalized,
                                             icon: currentDateIdeaResponse.summary.season.icon,
                                             color: .appSecondary)
                                .padding(.leading, 6)
                                
                                CategoryPill(text: currentDateIdeaResponse.summary.cost_level.displayName,
                                             icon: currentDateIdeaResponse.summary.cost_level.icon,
                                             color: .appAccent)
                                .padding(.leading, 6)
                            }
                            .padding(.bottom, 6)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(currentDateIdeaResponse.summary.tags, id: \.id) { tag in
                                    CategoryPill(text: tag.title, icon: tag.icon, color: .gray)
                                        .padding(.leading, 6)
                                }
                            }
                        }
                        .padding(.bottom, 4)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Location and duration
                        HStack(spacing: 16) {
                            if currentDateIdeaResponse.summary.content_type != .recipe {
                                InfoItem(icon: "mappin.and.ellipse", text: currentDateIdeaResponse.summary.location)
                            }
                            InfoItem(icon: "clock", text: currentDateIdeaResponse.summary.duration)
                        }
                        .padding(.horizontal)
                        
                        // Summary section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sectionTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(currentDateIdeaResponse.summary.summary)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)
                        
                        // Required items (only show if not a recipe and no itinerary - recipes and itineraries show this inside their views)
                        if !currentDateIdeaResponse.summary.required_items.isEmpty && (currentDateIdeaResponse.summary.suggested_itinerary == nil && currentDateIdeaResponse.summary.recipe_metadata == nil){
                            RequiredItemsSection(requiredItems: currentDateIdeaResponse.summary.required_items)
                                .padding(.horizontal)
                        }
                        
                        // Itinerary section
                        if let itinerary = currentItinerary, !itinerary.isEmpty && currentDateIdeaResponse.summary.recipe_metadata == nil {
                            if canEdit {
                                EditableItineraryView(
                                    itineraryItems: itinerary,
                                    requiredItems: currentRequiredItems,
                                    totalDuration: currentDateIdeaResponse.summary.duration,
                                    location: currentDateIdeaResponse.summary.location,
                                    onSave: { updatedItems, updatedEquipment in
                                        viewModel.updateItinerary(
                                            ideaId: currentDateIdeaResponse.id,
                                            itineraryItems: updatedItems,
                                            requiredItems: updatedEquipment,
                                            groupId: groupId
                                        )
                                    },
                                    onCancel: {
                                        viewModel.cancelItineraryEdit()
                                    }
                                )
                                .padding(.bottom, 16)
                                .padding(.horizontal)
                            } else {
                                // Show read-only itinerary view if user cannot edit
                                ItineraryView(
                                    itineraryItems: itinerary,
                                    requiredItems: currentRequiredItems,
                                    totalDuration: currentDateIdeaResponse.summary.duration,
                                    location: currentDateIdeaResponse.summary.location
                                )
                                .padding(.bottom, 16)
                                .padding(.horizontal)
                            }
                        }
                        
                        // Recipe section
                        if let recipeMetadata = currentRecipeMetadata {
                            if canEdit {
                                EditableRecipeView(
                                    recipeMetadata: recipeMetadata,
                                    requiredItems: currentRequiredItems,
                                    onSave: { updatedMetadata, updatedItems in
                                        viewModel.updateRecipe(
                                            ideaId: currentDateIdeaResponse.id,
                                            recipeMetadata: updatedMetadata,
                                            requiredItems: updatedItems,
                                            groupId: groupId
                                        )
                                    },
                                    onCancel: {
                                        viewModel.cancelRecipeEdit()
                                    }
                                )
                                .padding(.bottom, 16)
                                .padding(.horizontal)
                            } else {
                                // Show read-only recipe view if user cannot edit
                                RecipeView(recipeMetadata: recipeMetadata, requiredItems: currentRequiredItems)
                                    .padding(.bottom, 16)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Reactions Card
                        IdeaReactionsCard(ideaId: currentDateIdeaResponse.id, groupId: groupId)
                            .padding(.horizontal)
                            .padding(.vertical, 8)

                        // Comments Section
                        CommentSection(ideaId: currentDateIdeaResponse.id, groupId: groupId)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                            .id("commentsSection")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // Initialize view model with current data
                viewModel.setCurrentDateIdea(dateIdea)
                
                // Fetch latest data from backend in the background
                viewModel.fetchLatestActivityData(for: dateIdea.id)
                
                // Fetch author user data if needed
                fetchAuthorUserIfNeeded()
                
                if scrollToComments {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("commentsSection", anchor: .top)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { notification in
                // If the updated user is the author of this idea, update local state
                if let updatedUser = notification.userInfo?["updatedUser"] as? User,
                   let authorId = currentDateIdeaResponse.user_id,
                   updatedUser.id == authorId {
                    authorUser = updatedUser
                    print("🔄 Updated author user for idea \(currentDateIdeaResponse.id) with new profile data")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .ideaVisibilityUpdated)) { notification in
                // Update local state if this idea's visibility was changed from another part of the app
                if let ideaId = notification.userInfo?["ideaId"] as? String,
                   let isPublic = notification.userInfo?["isPublic"] as? Bool,
                   ideaId == currentDateIdeaResponse.id {
                    
                    // Update the view model's dateIdeaResponse to reflect the new visibility
                    if var updatedResponse = viewModel.dateIdeaResponse {
                        updatedResponse = DateIdeaResponse(
                            id: updatedResponse.id,
                            summary: updatedResponse.summary,
                            title: updatedResponse.title,
                            description: updatedResponse.description,
                            thumbnail_b64: updatedResponse.thumbnail_b64,
                            thumbnail_url: updatedResponse.thumbnail_url,
                            video_url: updatedResponse.video_url,
                            videoMetadata: updatedResponse.videoMetadata,
                            original_source_url: updatedResponse.original_source_url,
                            user_id: updatedResponse.user_id,
                            user_name: updatedResponse.user_name,
                            created_at: updatedResponse.created_at,
                            isPublic: isPublic
                        )
                        viewModel.dateIdeaResponse = updatedResponse
                        viewModel.dateIdea = updatedResponse.summary
                        print("🔄 DateIdeaDetailView: Updated visibility for idea \(ideaId): \(isPublic ? "Public" : "Private")")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .ideaMetadataUpdated)) { notification in
                // Update local state if this idea's metadata was changed from another part of the app
                if let ideaId = notification.userInfo?["ideaId"] as? String,
                   let updatedIdea = notification.userInfo?["updatedIdea"] as? DateIdeaResponse,
                   ideaId == currentDateIdeaResponse.id {
                    
                    // Update the view model's data with the updated idea
                    viewModel.dateIdeaResponse = updatedIdea
                    viewModel.dateIdea = updatedIdea.summary
                    print("🔄 DateIdeaDetailView: Updated metadata for idea \(ideaId)")
                }
            }
            .toolbar {
                // Only show the options menu for now (remove Watch button)
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Options menu
                    Menu {
                        if let src = currentDateIdeaResponse.original_source_url,
                           let url = URL(string: src) {
                            Button {
                                openURL(url)
                            } label: {
                                Label("Open Source", systemImage: "link")
                            }
                            
                            Button {
                                UIPasteboard.general.string = src
                                toastManager.success("Copied to clipboard")
                            } label: {
                                Label("Copy Source Link", systemImage: "doc.on.clipboard")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Options")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareToGroupView(idea: currentDateIdeaResponse, isPresented: $showShareSheet, toastManager: toastManager)
            }
            .sheet(isPresented: $showingBlockUser) {
                if let user = authorUser ?? (currentDateIdeaResponse.user_id != nil ? User(id: currentDateIdeaResponse.user_id!, name: currentDateIdeaResponse.user_name) : nil) {
                    BlockUserView(user: user, isPresented: $showingBlockUser)
                        .environmentObject(toastManager)
                }
            }
            .navigationBarHidden(hideNavigationBar)
            .withAppBackground()
        }
    }
    
    // MARK: - Helper Properties
    
    /// Returns the current date idea response, prioritizing updated data from view model
    private var currentDateIdeaResponse: DateIdeaResponse {
        return viewModel.dateIdeaResponse ?? dateIdea
    }
    
    /// Returns the current recipe metadata, prioritizing updated data from view model
    private var currentRecipeMetadata: RecipeMetadata? {
        return viewModel.dateIdeaResponse?.summary.recipe_metadata ?? dateIdea.summary.recipe_metadata
    }
    
    /// Returns the current itinerary items, prioritizing updated data from view model
    private var currentItinerary: [ItineraryItem]? {
        return viewModel.dateIdeaResponse?.summary.suggested_itinerary ?? dateIdea.summary.suggested_itinerary
    }
    
    /// Returns the current required items, prioritizing updated data from view model
    private var currentRequiredItems: [String] {
        return viewModel.dateIdeaResponse?.summary.required_items ?? dateIdea.summary.required_items
    }
    
    // MARK: - Author Section
    
    @ViewBuilder
    private var authorSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Author avatar with subtle shadow
                ZStack {
                    if isLoadingAuthor {
                        // Elegant loading placeholder
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.gray.opacity(0.1),
                                        Color.gray.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        let user = authorUser ?? User(id: currentDateIdeaResponse.user_id ?? "", name: currentDateIdeaResponse.user_name ?? "Unknown")
                        NavigationLink(destination: UserProfileView(user: user)) {
                            ProfileImage(user: user, diam: 44)
                                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Author info with improved typography
                VStack(alignment: .leading, spacing: 3) {
                    // Author name with reduced styling
                    Text(authorUser?.displayName ?? currentDateIdeaResponse.user_name ?? "Unknown")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Creation time with subtle styling
                    if let createdAtTimestamp = currentDateIdeaResponse.created_at {
                        let createdAtDate = Date(timeIntervalSince1970: TimeInterval(createdAtTimestamp))
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                            
                            Text("\(friendlyTimeAgoString(from: createdAtDate))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Options menu with block user functionality
                Menu {
                    Button(role: .destructive) {
                        showingBlockUser = true
                    } label: {
                        Label("Block User", systemImage: "person.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.appSurface)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.adaptiveCardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }
    
    // MARK: - User Data Fetching
    
    private func fetchAuthorUserIfNeeded() {
        guard let userId = currentDateIdeaResponse.user_id,
              let currentUserId = authVM.user?.uid,
              userId != currentUserId else { return }
        
        // Check if we already have the user or are loading
        if authorUser != nil || isLoadingAuthor { return }
        
        // First check cache - but force refresh if profile data is stale
        if let cachedUser = UserCache.shared.getUser(id: userId, allowStaleProfileData: false) {
            authorUser = cachedUser
            return
        }
        
        // Fetch from network if not cached or profile data is stale
        isLoadingAuthor = true
        NetworkClient.shared.getUsers(with: [userId], forceRefreshStaleProfiles: true) { result in
            DispatchQueue.main.async {
                self.isLoadingAuthor = false
                switch result {
                case .success(let users):
                    if let user = users.first {
                        self.authorUser = user
                        print("🔄 Fetched author data for \(user.displayName)")
                    } else {
                        // Fallback to basic user object
                        self.authorUser = User(id: userId, name: self.currentDateIdeaResponse.user_name)
                    }
                case .failure:
                    // Fallback to basic user object on network failure
                    self.authorUser = User(id: userId, name: self.currentDateIdeaResponse.user_name)
                }
            }
        }
    }
}

struct CategoryPill: View {
    let text: String
    let icon: String?
    
    // Auto-select a color if none provided
    var colorPair: ColorPair
    
    init(text: String, icon: String? = nil, color: Color? = nil) {
        self.text = text
        self.icon = icon
        
        // If no color is provided, select one based on the text
        if let color = color {
            self.colorPair = ColorPair(background: color.opacity(0.2), foreground: color)
        } else {
            self.colorPair = ColorPalette.randomPastelPair(for: text)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon, UIImage(systemName: icon) != nil {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(colorPair.background)
        .foregroundColor(colorPair.foreground)
        .cornerRadius(20)
    }
}

// A struct to hold background/foreground color pairs
struct ColorPair {
    let background: Color
    let foreground: Color
}

// Static palette of beautiful pastel colors
struct ColorPalette {
    // Collection of 10 pastel color pairs with light and dark variants
    static let pastelPairs: [ColorPairSet] = [
        ColorPairSet(
            light: ColorPair(background: Color(hex: "FFE2E2"), foreground: Color(hex: "F05454")), // Soft red
            dark: ColorPair(background: Color(hex: "4A1A1A"), foreground: Color(hex: "FF6B6B"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "FFEDDB"), foreground: Color(hex: "F0945E")), // Soft orange
            dark: ColorPair(background: Color(hex: "4A2E1C"), foreground: Color(hex: "FFA876"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "FFF8E1"), foreground: Color(hex: "EDAA25")), // Soft yellow
            dark: ColorPair(background: Color(hex: "3D3620"), foreground: Color(hex: "F7C843"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "E8F4D9"), foreground: Color(hex: "77AB59")), // Soft green
            dark: ColorPair(background: Color(hex: "253A1D"), foreground: Color(hex: "8BC571"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "D1EDF2"), foreground: Color(hex: "3D9FB4")), // Soft blue
            dark: ColorPair(background: Color(hex: "1C3A3F"), foreground: Color(hex: "55B5CC"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "D9D7F1"), foreground: Color(hex: "6A60A9")), // Soft purple
            dark: ColorPair(background: Color(hex: "2A2440"), foreground: Color(hex: "9B8ED4"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "F6D6EC"), foreground: Color(hex: "C2519A")), // Soft pink
            dark: ColorPair(background: Color(hex: "3F1F34"), foreground: Color(hex: "E069B2"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "E0F2C1"), foreground: Color(hex: "71A83B")), // Mint green
            dark: ColorPair(background: Color(hex: "243A18"), foreground: Color(hex: "89C253"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "FFDBCB"), foreground: Color(hex: "E56B4B")), // Peach
            dark: ColorPair(background: Color(hex: "4A2B1F"), foreground: Color(hex: "FF8363"))
        ),
        ColorPairSet(
            light: ColorPair(background: Color(hex: "D6E5FA"), foreground: Color(hex: "4A7FC1")), // Sky blue
            dark: ColorPair(background: Color(hex: "1E2A3A"), foreground: Color(hex: "6297D9"))
        )
    ]
    
    static func randomPastelPair(for text: String) -> ColorPair {
        // Fold each byte into an index in [0..<pastelPairs.count]
        let count = pastelPairs.count
        let idx = text.utf8.reduce(0) { (currentIndex, byte) in
            // add the byte, then mod to keep it small
            (currentIndex + Int(byte)) % count
        }
        return pastelPairs[idx].current
    }
}

// Updated ColorPair structure to support light/dark modes
struct ColorPairSet {
    let light: ColorPair
    let dark: ColorPair
    
    var current: ColorPair {
        // This will be evaluated at runtime based on current appearance
        ColorPair(
            background: Color(light: light.background, dark: dark.background),
            foreground: Color(light: light.foreground, dark: dark.foreground)
        )
    }
}

struct TagPill: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .foregroundColor(.gray)
            .cornerRadius(20)
    }
}

struct InfoItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.appPrimary)
            
            Text(text)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
    }
}

#Preview {
    let sampleItinerary = [
        ItineraryItem(
            time: "Day 1 - Morning",
            title: "Arrival & Setup",
            activity: "Arrive at Central Park and find a good spot near the lake",
            duration: "30 minutes",
            location: "East entrance",
            notes: "Look for shady areas near the lake"
        ),
        ItineraryItem(
            time: "Late Afternoon",
            title: "Picnic Time",
            activity: "Set up your picnic and enjoy the sunset views with your partner",
            duration: "2 hours",
            location: "Sheep Meadow",
            notes: "Best views are from the west side"
        ),
        ItineraryItem(
            time: "Evening",
            title: "Romantic Walk",
            activity: "Pack up and take a romantic night walk around the illuminated paths",
            duration: "1 hour",
            location: "Around the park",
            notes: nil
        )
    ]
    
    let sampleRecipeMetadata = RecipeMetadata(
        cuisine_type: "Italian",
        difficulty_level: "Easy",
        servings: "4",
        prep_time: "15 minutes",
        cook_time: "30 minutes",
        ingredients: [
            "2 cups of pasta",
            "1 jar of marinara sauce",
            "1 lb ground beef",
            "1 onion, diced",
            "2 cloves garlic, minced",
            "1 cup shredded mozzarella cheese"
        ],
        instructions: [
            "Bring a large pot of salted water to boil and cook pasta according to package directions",
            "In a large skillet, brown the ground beef over medium-high heat",
            "Add diced onion and garlic to the beef and cook until onion is translucent",
            "Stir in the marinara sauce and simmer for 10 minutes",
            "Drain pasta and serve topped with meat sauce and mozzarella cheese"
        ]
    )
    
    let mockRecipeIdea = DateIdea(
        title: "Homemade Spaghetti Bolognese",
        summary: "A delicious and comforting Italian pasta dish perfect for a cozy dinner at home. This classic recipe combines perfectly seasoned ground beef with rich marinara sauce.",
        content_type: .recipe,
        sales_pitch: "Create a romantic Italian dinner at home with this authentic and delicious recipe!",
        activity: Activity(title: "Cooking", icon: "fork.knife"),
        location: "at home",
        season: .indoor,
        duration: "45 minutes",
        cost_level: .low,
        required_items: ["Large pot", "Skillet", "Wooden spoon", "Strainer"],
        tags: [Tag(title: "Romantic", icon: "heart.fill"), Tag(title: "Comfort Food", icon: "house.fill"), Tag(title: "Italian", icon: "globe")],
        suggested_itinerary: nil,
        recipe_metadata: sampleRecipeMetadata
    )
    
    let mockDateIdea = DateIdea(
        title: "Sunset Picnic in the Park",
        summary: "Enjoy a romantic evening with your partner watching the sunset while having a picnic at a local park. Bring along wine, cheese, and fruits for a perfect evening.",
        content_type: .dateIdea,
        sales_pitch: "Create an unforgettable evening under the fading sky with delicious treats and the one you love!",
        activity: Activity(title: "Outdoors", icon: "sun.max"),
        location: "Central Park, NYC",
        season: .summer,
        duration: "2-3 hours",
        cost_level: .low,
        required_items: ["Picnic blanket", "Wine and glasses", "Cheese and crackers", "Portable speaker"],
        tags: [Tag(title: "Romantic", icon: "heart.fill"), Tag(title: "relaxing", icon: "moon"), Tag(title: "nature", icon: "leaf")],
        suggested_itinerary: sampleItinerary
    )
    
    // Show recipe example
    DateIdeaDetailView(dateIdea: DateIdeaResponse(id: "recipe-id", summary: mockRecipeIdea, title: mockRecipeIdea.title, description: mockRecipeIdea.sales_pitch, thumbnail_b64: nil, thumbnail_url: nil, video_url: nil, videoMetadata: nil, original_source_url: nil, user_id: nil, user_name: nil, created_at: nil, isPublic: false), viewModel: DateIdeaViewModel(toast: ToastManager()))
}
