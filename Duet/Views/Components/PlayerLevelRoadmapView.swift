//
//  PlayerLevelRoadmapView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI

struct PlayerLevelRoadmapView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var welcomeCreditService = WelcomeCreditService.shared
    let currentLevel: PlayerLevel
    let totalUserIdeas: Int
    
    private let levelDescriptions: [PlayerLevel: String] = [
        .ideaSpark: "You're just getting started on your creative journey! Every great idea begins with a single spark of inspiration. Keep exploring and let your curiosity guide you.",
        .ideaIgniter: "Your creative fire is growing stronger! You're building momentum and turning sparks into flames. Your ideas are starting to take shape and come alive.",
        .creativeFlame: "You're in full creative flow! Your imagination burns bright with confidence and passion. Ideas dance through your mind like flames in the wind.",
        .innovationStar: "You've reached the pinnacle of creative mastery! Your innovative spirit shines like a beacon, inspiring others and illuminating new possibilities."
    ]
    
    private let levelRequirements: [PlayerLevel: String] = [
        .ideaSpark: "15 ideas",
        .ideaIgniter: "40 ideas",
        .creativeFlame: "90 ideas",
        .innovationStar: "90+ ideas"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header Section
                    headerSection
                    
                    // Levels Section
                    VStack(spacing: 0) {
                        ForEach(Array(PlayerLevel.allCases.enumerated()), id: \.element) { index, level in
                            VStack(spacing: 0) {
                                PlayerLevelCard(
                                    level: level,
                                    description: levelDescriptions[level] ?? "",
                                    requirement: levelRequirements[level] ?? "",
                                    isCurrentLevel: level == currentLevel,
                                    isUnlocked: isLevelUnlocked(level)
                                )
                                
                                // Show connecting arrow if not the last level
                                if index < PlayerLevel.allCases.count - 1 {
                                    let nextLevel = PlayerLevel.allCases[index + 1]
                                    LevelConnector(
                                        fromLevel: level,
                                        toLevel: nextLevel,
                                        ideasNeeded: ideasNeededForNextLevel(from: level),
                                        isUnlocked: isLevelUnlocked(nextLevel)
                                    )
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .withAppBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimary)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.2),
                                Color.yellow.opacity(0.1),
                                Color.purple.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Player Levels")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Track your creative journey as you grow from a spark to a star")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    private var bonusCreditsCallout: some View {
        HStack(spacing: 12) {
            // Star icon
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundColor(.appAccent)
                .frame(width: 20, height: 20)
                .background(Color.appAccentLightBackground)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Level Up Bonus")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Earn +\(welcomeCreditService.levelUpBonus) credits when you reach a new level!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func isLevelUnlocked(_ level: PlayerLevel) -> Bool {
        // Calculate what level should be unlocked based on actual idea count
        let calculatedLevel = PlayerLevel(ideaCount: totalUserIdeas)
        let calculatedLevelIndex = PlayerLevel.allCases.firstIndex(of: calculatedLevel) ?? 0
        let checkLevelIndex = PlayerLevel.allCases.firstIndex(of: level) ?? 0
        
        // A level is unlocked if it's at or below the calculated level based on ideas
        return checkLevelIndex <= calculatedLevelIndex
    }
    
    private func ideasNeededForNextLevel(from level: PlayerLevel) -> String {
        switch level {
        case .ideaSpark:
            let needed = max(0, 15 - totalUserIdeas)
            return needed > 0 ? "\(needed) more \(needed == 1 ? "idea" : "ideas") needed" : "Level unlocked!"
        case .ideaIgniter:
            let needed = max(0, 40 - totalUserIdeas)
            return needed > 0 ? "\(needed) more \(needed == 1 ? "idea" : "ideas") needed" : "Level unlocked!"
        case .creativeFlame:
            let needed = max(0, 90 - totalUserIdeas)
            return needed > 0 ? "\(needed) more \(needed == 1 ? "idea" : "ideas") needed" : "Level unlocked!"
        case .innovationStar:
            return "" // No next level
        }
    }
}

struct PlayerLevelCard: View {
    let level: PlayerLevel
    let description: String
    let requirement: String
    let isCurrentLevel: Bool
    let isUnlocked: Bool
    
    @State private var animateGlow = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            VStack(alignment: .leading, spacing: 16) {
                // Header with icon and title
                HStack(spacing: 16) {
                    // Level icon with enhanced styling
                    ZStack {
                        Circle()
                            .fill(level.backgroundColor)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(level.foregroundColor.opacity(0.3), lineWidth: 1)
                            )
                        
                        Image(systemName: level.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(level.foregroundColor)
                    }
                    .scaleEffect(isCurrentLevel ? 1.1 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isCurrentLevel)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(level.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            if isCurrentLevel {
                                Text("Current")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(level.foregroundColor.opacity(0.6))
                                    )
                            }
                        }
                        
                        Text(requirement)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Lock/unlock indicator
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                
                // Description
                Text(description)
                    .font(.body)
                    .foregroundColor(isUnlocked ? .primary : .secondary.opacity(0.7))
                    .lineSpacing(2)
                    .opacity(isUnlocked ? 1.0 : 0.6)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: level.foregroundColor.opacity(isCurrentLevel ? 0.3 : 0.15),
                        radius: isCurrentLevel ? 12 : 8,
                        x: 0,
                        y: isCurrentLevel ? 6 : 3
                    )
            )
            .overlay(
                // Level-specific border with enhanced glow for current level
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        level.foregroundColor.opacity(
                            isCurrentLevel ? (animateGlow ? 0.5 : 0.2) : 0.15
                        ),
                        lineWidth: isCurrentLevel ? 2 : 1
                    )
                    .animation(
                        isCurrentLevel ? 
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : 
                        .none,
                        value: animateGlow
                    )
            )
            .scaleEffect(isCurrentLevel ? 1.02 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isCurrentLevel)
        }
        .opacity(isUnlocked ? 1.0 : 0.7)
        .onAppear {
            if isCurrentLevel {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animateGlow = true
                }
            }
        }
    }
}

struct LevelConnector: View {
    let fromLevel: PlayerLevel
    let toLevel: PlayerLevel
    let ideasNeeded: String
    let isUnlocked: Bool
    
    @State private var animateFlow = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Curved connecting line with gradient
            ZStack {
                // Background curved path
                CurvedArrowPath()
                    .stroke(
                        LinearGradient(
                            colors: [
                                fromLevel.foregroundColor.opacity(0.3),
                                toLevel.foregroundColor.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(height: 40)
                
                // Animated flowing gradient overlay
                CurvedArrowPath()
                    .stroke(
                        LinearGradient(
                            colors: [
                                fromLevel.foregroundColor.opacity(animateFlow ? 0.8 : 0.1),
                                toLevel.foregroundColor.opacity(animateFlow ? 0.1 : 0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(height: 40)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: animateFlow
                    )
            }
            
            // Ideas needed badge
            if !ideasNeeded.isEmpty {
                Text(ideasNeeded)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isUnlocked ? toLevel.foregroundColor : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(toLevel.backgroundColor.opacity(isUnlocked ? 0.8 : 0.3))
                            .overlay(
                                Capsule()
                                    .stroke(toLevel.foregroundColor.opacity(isUnlocked ? 0.3 : 0.1), lineWidth: 1)
                            )
                    )
                    .scaleEffect(isUnlocked ? 1.0 : 0.9)
                    .opacity(isUnlocked ? 1.0 : 0.6)
            }
        }
        .padding(.vertical, 16)
        .onAppear {
            // Start animation after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateFlow = true
            }
        }
    }
}

// Custom curved arrow path
struct CurvedArrowPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let startPoint = CGPoint(x: rect.midX, y: rect.minY)
        let endPoint = CGPoint(x: rect.midX, y: rect.maxY)
        
        // Create a subtle S-curve
        let controlPoint1 = CGPoint(x: rect.midX + 20, y: rect.height * 0.3)
        let controlPoint2 = CGPoint(x: rect.midX - 20, y: rect.height * 0.7)
        
        path.move(to: startPoint)
        path.addCurve(to: endPoint, control1: controlPoint1, control2: controlPoint2)
        
        return path
    }
}

#Preview {
    PlayerLevelRoadmapView(currentLevel: .innovationStar, totalUserIdeas: 90)
}
