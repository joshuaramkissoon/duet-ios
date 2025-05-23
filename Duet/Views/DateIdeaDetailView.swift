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
    
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: DateIdeaViewModel
    @State private var showShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.videoUrl.isEmpty, let url = URL(string: viewModel.videoUrl) {
                    HStack {
                        Spacer()
                        CachedVideoView(remoteURL: url, width: UIScreen.main.bounds.width - 100)
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
                        .padding(.bottom, 4)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Location and duration
                    HStack(spacing: 16) {
                        InfoItem(icon: "mappin.and.ellipse", text: dateIdea.summary.location)
                        InfoItem(icon: "clock", text: dateIdea.summary.duration)
                    }
                    .padding(.horizontal)
                    
                    // Sales pitch
                    QuoteCard(text: dateIdea.summary.sales_pitch)
                        .padding(.horizontal)
                    
                    // Summary section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About This Date")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(dateIdea.summary.summary)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                    
                    // Required items
                    if !dateIdea.summary.required_items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What You'll Need")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(dateIdea.summary.required_items, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.appPrimary)
                                        
                                        Text(item)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if let itinerary = dateIdea.summary.suggested_itinerary, !itinerary.isEmpty {
                        ItineraryView(itineraryItems: itinerary)
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
                }
            }
        }
        .onDisappear {
            
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
    
    let mockDateIdea = DateIdea(
        title: "Sunset Picnic in the Park",
        summary: "Enjoy a romantic evening with your partner watching the sunset while having a picnic at a local park. Bring along wine, cheese, and fruits for a perfect evening.",
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
    DateIdeaDetailView(dateIdea: DateIdeaResponse(id: "id", summary: mockDateIdea, title: mockDateIdea.title, description: mockDateIdea.sales_pitch, thumbnail_b64: nil, thumbnail_url: nil, video_url: "http://example.com", original_source_url: nil), viewModel: DateIdeaViewModel(toast: ToastManager()))
}
