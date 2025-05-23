import SwiftUI

struct ItineraryView: View {
    let itineraryItems: [ItineraryItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggested Itinerary")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                ForEach(Array(itineraryItems.enumerated()), id: \.element.id) { index, item in
                    ItineraryItemView(item: item, isLast: index == itineraryItems.count - 1)
                        .padding(.horizontal, 16)
                }
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

struct ItineraryItemView: View {
    let item: ItineraryItem
    let isLast: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Time indicator with connecting line
//                TimelineNode(isLast: isLast)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Time
                    HStack(alignment: .center) {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 14, height: 14)
                        Text(item.time)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                    }
                    
                    // Title if available
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                        .padding(.bottom, 1)
                    
                    // Activity description
                    Text(item.activity)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Optional fields
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
                .padding(.leading, 8)
                
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
    ItineraryView(itineraryItems: sampleItinerary)
}
