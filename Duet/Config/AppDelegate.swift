//
//  AppDelegate.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 19/05/2025.
//

import Foundation
import UIKit
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var backgroundCompletionHandler: (() -> Void)?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Background URL Session Handling
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        print("📱 App handling background events for session: \(identifier)")
        
        // Store the completion handler to be called when background events finish
        backgroundCompletionHandler = completionHandler
        
        // Ensure NetworkClient background session is alive and will handle the events
        _ = NetworkClient.shared
    }
}
