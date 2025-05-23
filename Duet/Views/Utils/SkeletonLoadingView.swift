//
//  SkeletonLoadingView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 21/05/2025.
//

import SwiftUI

struct SkeletonLoadingView: View {
    let count: Int
    @State private var shimmer = false
    
    init(count: Int = 3) {
        self.count = count
    }
    
    var placeholder: some View {
        VStack(alignment: .center) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)

            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 14)
//                .padding(.leading, 8)
        }
        .padding(8)
    }
    
    var shimmerOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.6), Color.clear]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .rotationEffect(.degrees(30))
        .offset(x: shimmer ? 200 : -200)
        .animation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false), value: shimmer)
    }
    
    var body: some View {
        HStack {
            ForEach(0..<count, id: \.self) { _ in
                placeholder
                    .overlay(shimmerOverlay.mask(placeholder))
                    .padding(.vertical, 6)
                    .redacted(reason: .placeholder)
            }
        }
        .onAppear {
            shimmer = true
        }
    }
}

#Preview {
    SkeletonLoadingView()
}
