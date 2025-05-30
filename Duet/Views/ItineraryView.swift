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

struct ItineraryItemsSection: View {
    let itineraryItems: [ItineraryItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(itineraryItems.enumerated()), id: \.element.id) { index, item in
                    ItineraryItemView(item: item, isLast: index == itineraryItems.count - 1)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }
}

struct ItineraryItemView: View {
    let item: ItineraryItem
    let isLast: Bool
    
    // drives all three circles
    @State private var animatePulse = false
    // random per-shape start delays, stable per-item
    private let randomDelays = [
        Double.random(in: 0...0.5),
        Double.random(in: 0...0.5),
        Double.random(in: 0...0.5)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                
                // ─── pulsing indicator ─────────────────────────────────
                ZStack {
                    // outer glow
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(width: 20, height: 20)
                        .scaleEffect(animatePulse ? 1.5 : 1.0)
                        .opacity(animatePulse ? 0.3 : 0.8)
                        .animation(
                            Animation
                                .easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(randomDelays[0]),
                            value: animatePulse
                        )
                    
                    // mid glow
                    Circle()
                        .fill(Color.appPrimary.opacity(0.25))
                        .frame(width: 16, height: 16)
                        .scaleEffect(animatePulse ? 1.3 : 1.0)
                        .opacity(animatePulse ? 0.4 : 0.9)
                        .animation(
                            Animation
                                .easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(randomDelays[1]),
                            value: animatePulse
                        )
                    
                    // core
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 12, height: 12)
                        .scaleEffect(animatePulse ? 1.1 : 1.0)
                        .animation(
                            Animation
                                .easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(randomDelays[2]),
                            value: animatePulse
                        )
                }
                // **fixed** layout box so nothing ever shifts
                .frame(width: 30, height: 30)
                .onAppear { animatePulse = true }
                
                // ─── text content ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.time)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimary)
                    
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                        .padding(.bottom, 1)
                    
                    Text(item.activity)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let duration = item.duration {
                        DetailRow(icon: "clock", text: duration)
                    }
                    if let location = item.location {
                        DetailRow(icon: "mappin.and.ellipse", text: location)
                    }
                    if let notes = item.notes {
                        DetailRow(icon: "text.quote", text: notes)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            
            if !isLast {
                Divider()
                    .padding(.leading, 32)
            }
        }
    }
}

struct TimelineNode: View {
    let isLast: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            // Circle node
            Circle()
                .fill(Color.appPrimary)
                .frame(width: 14, height: 14)
            
//            // Connecting line if not the last item
//            if !isLast {
//                Rectangle()
//                    .fill(Color.appPrimary.opacity(0.3))
//                    .frame(width: 2)
//                    .offset(y: 14) // Start below the circle
//            }
        }
        .frame(width: 14)
        .padding(.trailing, 6)
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(.gray)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
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
