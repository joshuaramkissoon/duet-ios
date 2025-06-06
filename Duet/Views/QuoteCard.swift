//
//  QuoteCard.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI

struct QuoteCard: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top quote mark
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundColor(.appPrimary)
                .padding(.leading, 4)
            
            // Main quote text
            Text(text)
                .italic()
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .lineSpacing(4)
            
            // Bottom line with icon
            HStack {
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.appPrimary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                // Layered background for depth
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appSurface)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                
                // Decorative border on left side
                Rectangle()
                    .fill(Color.appPrimary)
                    .frame(width: 4)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Subtle pattern background
                Color.appPrimary.opacity(0.05)
                    .mask(
                        GeometryReader { geo in
                            Path { path in
                                for i in stride(from: 0, to: geo.size.width, by: 20) {
                                    for j in stride(from: 0, to: geo.size.height, by: 20) {
                                        let rect = CGRect(x: i, y: j, width: 3, height: 3)
                                        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 1.5, height: 1.5))
                                    }
                                }
                            }
                        }
                    )
            }
            .cornerRadius(16)
        )
    }
}

// A more subtle version for when you want less visual impact
struct QuoteCardSubtle: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left quote marks
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundColor(.appPrimary)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                // Quote text
                Text(text)
                    .italic()
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                
                // Bottom sparkle
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.appPrimary.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.appPrimary.opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    QuoteCard(text: "Quote card")
}
