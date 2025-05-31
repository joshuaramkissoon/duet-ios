//
//  Schedule.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                PulsingIndicator()
                
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