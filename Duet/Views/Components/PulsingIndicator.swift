//
//  PulsingIndicator.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 31/05/2025.
//

import SwiftUI

struct PulsingIndicator: View {
    @State private var animatePulse = false
    
    // Random per-shape start delays, stable per-indicator
    private let randomDelays = [
        Double.random(in: 0...0.5),
        Double.random(in: 0...0.5),
        Double.random(in: 0...0.5)
    ]
    
    var body: some View {
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
        // Fixed layout box so nothing ever shifts
        .frame(width: 30, height: 30)
        .onAppear { 
            animatePulse = true 
        }
    }
} 