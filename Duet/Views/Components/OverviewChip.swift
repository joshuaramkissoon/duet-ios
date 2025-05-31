//
//  OverviewChip.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct OverviewChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.7))
                .frame(width: 14)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 32)
        .background(color)
        .cornerRadius(16)
    }
}