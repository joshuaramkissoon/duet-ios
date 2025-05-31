import SwiftUI

struct ItineraryView: View {
    let itineraryItems: [ItineraryItem]
    let requiredItems: [String]
    let totalDuration: String
    let location: String
    
    @State private var isExpanded = false
    @State private var selectedTab: ItineraryTab = .equipment
    
    enum ItineraryTab: String, CaseIterable {
        case equipment = "What You Need"
        case schedule = "Schedule"
        
        var icon: String {
            switch self {
            case .equipment: return "bag"
            case .schedule: return "calendar"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and expand/collapse button
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Suggested Itinerary")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.midnightSlate)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(isExpanded ? "Less" : "More")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.appPrimary)
                            
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.appPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                    .padding(.horizontal, 16)
            }
            
            // Always visible overview section - show first few items or summary
            ItineraryOverviewSection(itineraryItems: itineraryItems, requiredItems: requiredItems, totalDuration: totalDuration, location: location)
                .padding(.horizontal, 16)
            
            // Expandable content with tab view
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    
                    // Tab selector
                    ItineraryTabSelector(
                        selectedTab: $selectedTab,
                        availableTabs: availableTabs
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Tab content
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .equipment:
                            if !requiredItems.isEmpty {
                                RequiredItemsSection(requiredItems: requiredItems)
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                            
                        case .schedule:
                            if !itineraryItems.isEmpty {
                                ItineraryItemsSection(itineraryItems: itineraryItems)
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onAppear {
            // Set initial tab to the first available one
            if let firstTab = availableTabs.first {
                selectedTab = firstTab
            }
        }
    }
    
    private var availableTabs: [ItineraryTab] {
        var tabs: [ItineraryTab] = []
        
        if !requiredItems.isEmpty {
            tabs.append(.equipment)
        }
        
        if !itineraryItems.isEmpty {
            tabs.append(.schedule)
        }
        
        return tabs
    }
}

struct ItineraryTabSelector: View {
    @Binding var selectedTab: ItineraryView.ItineraryTab
    let availableTabs: [ItineraryView.ItineraryTab]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(availableTabs, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(selectedTab == tab ? .white : .appPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTab == tab ? Color.appPrimary : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.appPrimary.opacity(0.08))
        )
    }
}

struct ItineraryOverviewSection: View {
    let itineraryItems: [ItineraryItem]
    let requiredItems: [String]
    let totalDuration: String
    let location: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.appPrimary)
                .padding(.top, 16)
            
            // Show summary info in horizontal scroll view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !itineraryItems.isEmpty {
                        OverviewChip(icon: "calendar", text: "\(itineraryItems.count) Activities", color: Color(hex: "E3F2FD")) // Soft blue
                    }
                    
                    if !requiredItems.isEmpty {
                        OverviewChip(icon: "bag", text: "\(requiredItems.count) Items", color: Color(hex: "E8F5E8")) // Soft green
                    }
                    
                    // Show total duration if available
                    if !totalDuration.isEmpty {
                        OverviewChip(icon: "clock", text: totalDuration, color: Color(hex: "F3E5F5")) // Soft purple
                    }
                }
                .padding(.horizontal, 1) // Small padding to prevent clipping
            }
            
            // Show map if location is not "at home"
            if location.lowercased() != "at home" {
                LocationMapView(location: location, height: 120, hideOnFailure: true)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 12)
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
    ItineraryView(itineraryItems: sampleItinerary, requiredItems: ["Picnic basket", "Sunscreen", "Water bottle"], totalDuration: "3 hours", location: "Central Park")
}
