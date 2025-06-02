//
//  CreditUIManager.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation
import SwiftUI

final class CreditUIManager: ObservableObject {
    @Published var showPurchaseCreditsSheet: Bool = false
    @Published var showCreditsView: Bool = false
    
    // MARK: - Actions
    
    /// Show the purchase credits sheet
    func showPurchaseSheet() {
        showPurchaseCreditsSheet = true
    }
    
    /// Hide the purchase credits sheet
    func hidePurchaseSheet() {
        showPurchaseCreditsSheet = false
    }
    
    /// Show the main credits view/dashboard
    func showCreditsPage() {
        showCreditsView = true
    }
    
    /// Hide the main credits view/dashboard
    func hideCreditsPage() {
        showCreditsView = false
    }
    
    /// Handle insufficient credits scenario - shows purchase sheet
    func handleInsufficientCredits() {
        showPurchaseSheet()
    }
    
    /// Dismiss all credit-related sheets (useful for payment success)
    func dismissAllSheets() {
        showPurchaseCreditsSheet = false
        showCreditsView = false
    }
} 