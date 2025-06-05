//
//  CreditIcon.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI

// MARK: - Credit Icon System
enum CreditIconType {
    case creditBalance
    case usage
    case purchase
    case bonus
    case refund
    case levelUp
    case referral
    case unknown
    
    var iconName: String {
        switch self {
        case .creditBalance:
            return "creditcard.fill"
        case .usage:
            return "play.fill"
        case .purchase:
            return "creditcard.fill"
        case .bonus:
            return "gift.fill"
        case .refund:
            return "arrow.counterclockwise"
        case .levelUp:
            return "star.fill"
        case .referral:
            return "person.2.fill"
        case .unknown:
            return "circle.fill"
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .creditBalance, .purchase:
            return .appPrimary
        case .usage:
            return .appSecondary
        case .bonus, .levelUp:
            return .appAccent
        case .referral:
            return .warmOrange
        case .refund:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .creditBalance, .purchase:
            return .appPrimaryLightBackground
        case .usage:
            return .appSecondaryLightBackground
        case .bonus, .levelUp:
            return .appAccentLightBackground
        case .referral:
            return .softCream
        case .refund:
            return Color.orange.opacity(0.1)
        case .unknown:
            return Color.gray.opacity(0.1)
        }
    }
    
    static func from(transactionType: String) -> CreditIconType {
        switch transactionType.lowercased() {
        case "usage":
            return .usage
        case "purchase":
            return .purchase
        case "bonus":
            return .bonus
        case "level_up_bonus":
            return .levelUp
        case "refund":
            return .refund
        default:
            return .unknown
        }
    }
}

struct CreditIcon: View {
    let type: CreditIconType
    let size: Font
    let frameSize: CGFloat
    
    init(type: CreditIconType, size: Font = .title2, frameSize: CGFloat = 32) {
        self.type = type
        self.size = size
        self.frameSize = frameSize
    }
    
    var body: some View {
        Image(systemName: type.iconName)
            .font(size)
            .foregroundColor(type.foregroundColor)
            .frame(width: frameSize, height: frameSize)
            .background(type.backgroundColor)
            .clipShape(Circle())
    }
} 