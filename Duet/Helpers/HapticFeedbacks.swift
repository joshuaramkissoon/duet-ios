//
//  HapticFeedbacks.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 18/05/2025.
//


import UIKit

struct HapticFeedbacks {
    
    // MARK: - Functions:
    
    /// Triggers after any successful action:
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    /// Triggers when there is an error:
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    /// Soft feedback that is usually used when deleting or hiding something within the app:
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    /// Triggers when the selection changes:
    static func selectionChanges() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}