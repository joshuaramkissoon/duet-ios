//
//  DateIdeaDetailView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI
import AVKit

struct DateIdeaDetailView: View {
    let dateIdea: DateIdeaResponse
    var groupId: String? = nil
    var scrollToComments: Bool = false
    
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: DateIdeaViewModel
    @State private var showShareSheet = false
    
    private var sectionTitle: String {
        switch dateIdea.summary.content_type {
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
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !viewModel.videoUrl.isEmpty, let url = URL(string: viewModel.videoUrl) {
                        HStack {
                            Spacer()
                            CachedVideoView(
                                remoteURL: url, 
                                thumbnailB64: dateIdea.thumbnail_b64,
                                aspectRatio: dateIdea.videoMetadata?.aspectRatio ?? 16/9,
                                width: UIScreen.main.bounds.width - 100
                            )
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Title and basic info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(dateIdea.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        // Tags row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                CategoryPill(text: dateIdea.summary.activity.title,
                                             icon: dateIdea.summary.activity.icon,
                                             color: .appPrimary)
                                .padding(.leading, 6)
                                
                                CategoryPill(text: dateIdea.summary.season.rawValue.capitalized,
                                             icon: dateIdea.summary.season.icon,
                                             color: .appSecondary)
                                .padding(.leading, 6)
                                
                                CategoryPill(text: dateIdea.summary.cost_level.displayName,
                                             icon: dateIdea.summary.cost_level.icon,
                                             color: .appAccent)
                                .padding(.leading, 6)
                            }
                            .padding(.bottom, 6)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(dateIdea.summary.tags, id: \.id) { tag in
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
                            if dateIdea.summary.content_type != .recipe {
                                InfoItem(icon: "mappin.and.ellipse", text: dateIdea.summary.location)
                            }
                            InfoItem(icon: "clock", text: dateIdea.summary.duration)
                        }
                        .padding(.horizontal)
                        
                        // Summary section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sectionTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(dateIdea.summary.summary)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal)
                        
                        // Required items (only show if not a recipe - recipes show this inside RecipeView)
                        if !dateIdea.summary.required_items.isEmpty && (dateIdea.summary.suggested_itinerary == nil && dateIdea.summary.recipe_metadata == nil){
                            RequiredItemsSection(requiredItems: dateIdea.summary.required_items)
                                .padding(.horizontal)
                        }
                        
                        if let itinerary = dateIdea.summary.suggested_itinerary, !itinerary.isEmpty && dateIdea.summary.recipe_metadata == nil {
                            ItineraryView(itineraryItems: itinerary, requiredItems: dateIdea.summary.required_items, totalDuration: dateIdea.summary.duration, location: dateIdea.summary.location)
                                .padding(.bottom, 16)
                                .padding(.horizontal)
                        }
                        
                        if let recipeMetadata = dateIdea.summary.recipe_metadata {
                            RecipeView(recipeMetadata: recipeMetadata, requiredItems: dateIdea.summary.required_items)
                                .padding(.bottom, 16)
                                .padding(.horizontal)
                        }
                        
                        // Share to group
                        Button(action: {
                            showShareSheet = true
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "person.3.fill")
                                    .font(.body.bold())
                                Text("Share to Group")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding()
                            .background(Color.appPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)

                        // Comments Section
                        CommentSection(ideaId: dateIdea.id, groupId: groupId)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                            .id("commentsSection")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if scrollToComments {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("commentsSection", anchor: .top)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share to Group", systemImage: "person.3.fill")
                        }
                        
                        if let src = dateIdea.original_source_url,
                           let url = URL(string: src) {
                            Button {
                                openURL(url)
                            } label: {
                                Label("Open Source", systemImage: "link")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .accessibilityLabel("Options")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareToGroupView(idea: dateIdea, isPresented: $showShareSheet, toastManager: toastManager)
            }
            .withAppBackground()
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
    // Collection of 10 pastel color pairs (background, foreground)
    static let pastelPairs: [ColorPair] = [
        ColorPair(background: Color(hex: "FFE2E2"), foreground: Color(hex: "F05454")), // Soft red
        ColorPair(background: Color(hex: "FFEDDB"), foreground: Color(hex: "F0945E")), // Soft orange
        ColorPair(background: Color(hex: "FFF8E1"), foreground: Color(hex: "EDAA25")), // Soft yellow
        ColorPair(background: Color(hex: "E8F4D9"), foreground: Color(hex: "77AB59")), // Soft green
        ColorPair(background: Color(hex: "D1EDF2"), foreground: Color(hex: "3D9FB4")), // Soft blue
        ColorPair(background: Color(hex: "D9D7F1"), foreground: Color(hex: "6A60A9")), // Soft purple
        ColorPair(background: Color(hex: "F6D6EC"), foreground: Color(hex: "C2519A")), // Soft pink
        ColorPair(background: Color(hex: "E0F2C1"), foreground: Color(hex: "71A83B")), // Mint green
        ColorPair(background: Color(hex: "FFDBCB"), foreground: Color(hex: "E56B4B")), // Peach
        ColorPair(background: Color(hex: "D6E5FA"), foreground: Color(hex: "4A7FC1"))  // Sky blue
    ]
    
    static func randomPastelPair(for text: String) -> ColorPair {
        // Fold each byte into an index in [0..<pastelPairs.count]
        let count = pastelPairs.count
        let idx = text.utf8.reduce(0) { (currentIndex, byte) in
            // add the byte, then mod to keep it small
            (currentIndex + Int(byte)) % count
        }
        return pastelPairs[idx]
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
    DateIdeaDetailView(dateIdea: DateIdeaResponse(id: "recipe-id", summary: mockRecipeIdea, title: mockRecipeIdea.title, description: mockRecipeIdea.sales_pitch, thumbnail_b64: nil, thumbnail_url: nil, video_url: "http://example.com", videoMetadata: nil, original_source_url: nil, user_id: nil, user_name: nil, created_at: nil), viewModel: DateIdeaViewModel(toast: ToastManager()))
}
