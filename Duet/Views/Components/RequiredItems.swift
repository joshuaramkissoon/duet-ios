//
//  RequiredItems.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct EquipmentCard: View {
    let item: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.appAccent.opacity(0.08))
        .cornerRadius(8)
    }
}

struct RequiredItemsSection: View {
    let requiredItems: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
             // Beautiful equipment grid
             LazyVGrid(columns: [
                 GridItem(.flexible()),
                 GridItem(.flexible())
             ], spacing: 8) {
                 ForEach(Array(requiredItems.enumerated()), id: \.offset) { index, item in
                     EquipmentCard(item: item)
                 }
             }
             .padding(.top, 16)
             .padding(.bottom, 12)
        }
    }
}