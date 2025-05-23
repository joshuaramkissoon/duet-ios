//
//  ProfileImage.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 23/05/2025.
//

import SwiftUI

struct ProfileImage: View {
    let user: User
    let displayName: String
    let diam: CGFloat
    let font: Font
    let fontWeight: Font.Weight
    let fontSize: CGFloat
    
    init(user: User, diam: CGFloat = 50) {
        self.user = user
        self.diam = diam
        self.displayName = user.displayName
        self.font = diam >= 50 ? .headline : .caption
        self.fontWeight = diam >= 50 ? .bold : .medium
        self.fontSize = diam * 0.32
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                AbstractGradientBackground(seedString: user.id)
                    .frame(width: diam, height: diam)
                
                Text(user.initials)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .fontWeight(fontWeight)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
    }
}

struct UserProfileImage: View {
    let user: User
    let displayName: String
    let diam: CGFloat
    let font: Font
    
    init(user: User, diam: CGFloat = 50, font: Font = .headline, overrideDisplayName: String? = nil) {
        self.user = user
        self.diam = diam
        self.displayName = overrideDisplayName ?? user.displayName
        self.font = font
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ProfileImage(user: user, diam: diam)
            
            Text(displayName)
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    ProfileImage(user: User(id: UUID().uuidString, name: "Joshua Ramkissoon"))
}
