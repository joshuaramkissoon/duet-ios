//
//  AbstractGradientBackground.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 23/05/2025.
//
import SwiftUI

let colors: [Color] = [
    .appPrimary, .appSecondary, .appAccent, .blue, .purple, .teal, .pink,
    .mint, .cyan, .indigo, .orange, .yellow, .green, .red,
    Color(red: 0.9, green: 0.6, blue: 0.7), // Soft rose
    Color(red: 0.7, green: 0.5, blue: 0.9), // Lavender
    Color(red: 0.5, green: 0.8, blue: 0.9), // Sky blue
    Color(red: 0.9, green: 0.8, blue: 0.5), // Warm gold
    Color(red: 0.6, green: 0.9, blue: 0.7), // Sage green
    Color(red: 0.9, green: 0.7, blue: 0.5), // Peach
    Color(red: 0.8, green: 0.6, blue: 0.9), // Violet
    Color(red: 0.5, green: 0.9, blue: 0.8), // Aquamarine
    Color(red: 0.9, green: 0.5, blue: 0.6), // Coral
    Color(red: 0.7, green: 0.9, blue: 0.6), // Light lime
    Color(red: 0.6, green: 0.7, blue: 0.9), // Periwinkle
    Color(red: 0.9, green: 0.8, blue: 0.7), // Warm beige
    Color(red: 0.8, green: 0.9, blue: 0.6), // Chartreuse
    Color(red: 0.6, green: 0.8, blue: 0.7), // Seafoam
]

struct AbstractGradientBackground: View {
    let gradientColors: [Color]
    let ellipticalCenter: UnitPoint
    let angularCenter: UnitPoint
    
    init(seedString: String) {
        // Use seedString for unique, consistent colors
        let stableHash = seedString.djb2hash
        let firstIndex = stableHash % UInt(colors.count)
        let secondHash = seedString.appending("_offset").djb2hash
        let secondIndex = secondHash % UInt(colors.count)
        
        // Ensure we get two different colors with much more separation
        var adjustedSecondIndex = secondIndex
        let minSeparation = max(colors.count / 4, 3)
        if firstIndex == secondIndex || abs(Int(firstIndex) - Int(secondIndex)) < minSeparation {
            adjustedSecondIndex = (firstIndex + UInt(minSeparation)) % UInt(colors.count)
        }
        
        // Create randomized gradient centers based on seed
        let positionHash = seedString.appending("_position").djb2hash
        let centerX = Double((positionHash % 100)) / 100.0
        let centerY = Double(((positionHash >> 8) % 100)) / 100.0
        let angularCenterX = Double(((positionHash >> 16) % 100)) / 100.0
        let angularCenterY = Double(((positionHash >> 24) % 100)) / 100.0
        
        // Create more vibrant pastel versions for better contrast
        let firstColor = colors[Int(firstIndex)].opacity(0.6)
        let secondColor = colors[Int(adjustedSecondIndex)].opacity(0.5)
        
        self.gradientColors = [firstColor, secondColor]
        self.ellipticalCenter = UnitPoint(x: centerX, y: centerY)
        self.angularCenter = UnitPoint(x: angularCenterX, y: angularCenterY)
    }
    
    var body: some View {
        Circle()
            .fill(
                EllipticalGradient(
                    gradient: Gradient(colors: [
                        gradientColors[0],
                        gradientColors[1],
                        gradientColors[0].opacity(0.3),
                        gradientColors[1].opacity(0.7)
                    ]),
                    center: ellipticalCenter,
                    startRadiusFraction: 0.0,
                    endRadiusFraction: 1.4
                )
            )
            .overlay(
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: gradientColors[1].opacity(0.8), location: 0.0),
                                .init(color: Color.clear, location: 0.2),
                                .init(color: gradientColors[0].opacity(0.6), location: 0.4),
                                .init(color: Color.clear, location: 0.7),
                                .init(color: gradientColors[1].opacity(0.4), location: 1.0)
                            ]),
                            center: angularCenter
                        )
                    )
                    .blendMode(.overlay)
            )
    }
}

#Preview {
    AbstractGradientBackground(seedString: UUID().uuidString)
}
