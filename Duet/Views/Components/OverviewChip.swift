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
                .foregroundColor(.secondary)
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}