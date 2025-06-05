import Foundation
import UserNotifications
import UIKit
import SwiftUI

/// NotificationManager handles local notifications for completed idea processing.
/// It only sends notifications when the app is in the background to avoid interrupting active users.
/// Notifications deep link to the completed idea detail view when tapped.
@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var hasNotificationPermission = false
    @Published var notificationSettings: UNNotificationSettings?
    
    private override init() {
        super.init()
        setupNotificationCenter()
        Task {
            await checkNotificationSettings()
        }
    }
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Permission Management
    
    /// Requests notification permission from the user
    /// - Returns: Bool indicating if permission was granted
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            
            await checkNotificationSettings()
            
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
            
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }
    
    /// Checks current notification settings and updates published properties
    func checkNotificationSettings() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationSettings = settings
        hasNotificationPermission = settings.authorizationStatus == .authorized
        
        print("📱 Notification settings updated - Permission: \(hasNotificationPermission)")
    }
    
    // MARK: - Notification Scheduling
    
    /// Schedules a local notification for a completed idea, but only if app is not active
    /// - Parameters:
    ///   - ideaId: The ID of the completed idea
    ///   - ideaTitle: The title to display in the notification
    ///   - groupId: Optional group ID if this is a group idea
    func scheduleIdeaCompletedNotification(
        ideaId: String,
        ideaTitle: String,
        groupId: String? = nil
    ) {
        // Only send notification if app is not active
        guard !isAppActive() else {
            return
        }
        
        // Check permission status in real-time instead of relying on cached value
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationSettings = settings
                self?.hasNotificationPermission = settings.authorizationStatus == .authorized
                
                guard settings.authorizationStatus == .authorized else {
                    return
                }
                
                let content = UNMutableNotificationContent()
                content.title = ideaTitle
                content.body = "Your idea has finished processing, tap to view."
                content.sound = .default
                
                // Add user info for deep linking
                var userInfo: [String: Any] = [
                    "type": "idea_completed",
                    "ideaId": ideaId,
                    "ideaTitle": ideaTitle
                ]
                
                if let groupId = groupId {
                    userInfo["groupId"] = groupId
                }
                
                content.userInfo = userInfo
                
                // Immediate delivery (processing just completed)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                
                // Use ideaId as identifier so we can cancel if needed
                let request = UNNotificationRequest(
                    identifier: "idea_completed_\(ideaId)",
                    content: content,
                    trigger: trigger
                )
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Failed to schedule notification: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - App State Detection
    
    private func isAppActive() -> Bool {
        // Check if app is in active state
        let isActive = UIApplication.shared.applicationState == .active
        
        // Additional check for scene state if available
        if #available(iOS 13.0, *) {
            let hasActiveScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .contains { $0.activationState == .foregroundActive }
            
            return isActive && hasActiveScene
        }
        
        return isActive
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(for ideaId: String) {
        let identifier = "idea_completed_\(ideaId)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func cancelAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func clearAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - Helper Methods
    
    func hasValidPermission() -> Bool {
        return hasNotificationPermission && 
               notificationSettings?.authorizationStatus == .authorized
    }
    
    func logNotificationStatus() {
        print("📱 Notification Status:")
        print("   - Permission: \(hasNotificationPermission)")
        print("   - App Active: \(isAppActive())")
        print("   - Authorization: \(notificationSettings?.authorizationStatus.rawValue ?? -1)")
    }
    
    // MARK: - Testing & Debug
    
    /// Schedules a test notification for debugging purposes
    /// This can be useful for testing notification functionality during development
    func scheduleTestNotification() {
        guard hasNotificationPermission else {
            print("❌ Cannot schedule test notification - no permission")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from Duet."
        content.sound = .default
        
        // Test notification in 3 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "test_notification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test notification: \(error)")
            } else {
                print("✅ Scheduled test notification (will appear in 3 seconds)")
            }
        }
    }
    
    /// Forces a notification to be scheduled regardless of app state (for testing)
    func forceScheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Forced Test Notification"
        content.body = "This notification was forced regardless of app state."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "forced_test_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule forced test notification: \(error)")
            } else {
                print("✅ Scheduled forced test notification")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Don't show notification when app is active (we handle this in scheduleIdeaCompletedNotification)
        completionHandler([])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String,
           type == "idea_completed",
           let ideaId = userInfo["ideaId"] as? String {
            
            let groupId = userInfo["groupId"] as? String
            
            // Post notification for deep linking
            let deepLinkInfo: [String: Any] = [
                "ideaId": ideaId,
                "groupId": groupId as Any
            ]
            
            NotificationCenter.default.post(
                name: .openCompletedIdea,
                object: nil,
                userInfo: deepLinkInfo
            )
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openCompletedIdea = Notification.Name("openCompletedIdea")
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
} 