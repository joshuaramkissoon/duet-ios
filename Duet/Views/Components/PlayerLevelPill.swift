//
//  PlayerLevelPill.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI

struct PlayerLevelPill: View {
    let level: PlayerLevel
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.icon)
                .font(.caption)
                .foregroundColor(level.foregroundColor)
            
            Text(level.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(level.foregroundColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(level.backgroundColor)
                .stroke(level.foregroundColor.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        PlayerLevelPill(level: .ideaSpark)
        PlayerLevelPill(level: .ideaIgniter)
        PlayerLevelPill(level: .creativeFlame)
        PlayerLevelPill(level: .innovationStar)
    }
    .padding()
} 