import Foundation
import SwiftUI

/// NavigationManager handles deep linking navigation throughout the app
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    // Published properties for navigation state
    @Published var selectedTab: Int = 0 // Default to Home tab
    @Published var pendingIdeaNavigation: PendingIdeaNavigation?
    
    private init() {}
    
    // MARK: - Deep Link Handling
    
    /// Navigate to a specific idea from a notification
    /// - Parameters:
    ///   - ideaId: The ID of the idea to navigate to
    ///   - groupId: Optional group ID if this is a group idea
    func navigateToIdea(ideaId: String, groupId: String?) {
        // Set to Home tab first
        selectedTab = 0
        
        // Set pending navigation
        pendingIdeaNavigation = PendingIdeaNavigation(
            ideaId: ideaId,
            groupId: groupId,
            timestamp: Date()
        )
        
        print("🧭 NavigationManager: Set pending navigation for idea \(ideaId)")
    }
    
    /// Clear pending navigation after it's been handled
    func clearPendingNavigation() {
        pendingIdeaNavigation = nil
        print("🧭 NavigationManager: Cleared pending navigation")
    }
    
    /// Navigate to a specific tab
    /// - Parameter tabIndex: The index of the tab to navigate to
    func navigateToTab(_ tabIndex: Int) {
        selectedTab = tabIndex
    }
}

// MARK: - Supporting Types

struct PendingIdeaNavigation: Equatable {
    let ideaId: String
    let groupId: String?
    let timestamp: Date
    
    static func == (lhs: PendingIdeaNavigation, rhs: PendingIdeaNavigation) -> Bool {
        return lhs.ideaId == rhs.ideaId && lhs.groupId == rhs.groupId
    }
} 