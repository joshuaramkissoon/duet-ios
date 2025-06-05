//
//  DuetApp.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI
import Firebase
import AVFoundation

@main
struct DuetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthenticationViewModel()
    @StateObject private var groupsVM = GroupsViewModel()
    @StateObject private var toastManager = ToastManager()
    @StateObject private var dateIdeaVM = DateIdeaViewModel(toast: ToastManager())
    @StateObject private var activityVM = ActivityHistoryViewModel()
    @StateObject private var exploreVM = ExploreViewModel()
    @StateObject private var processingManager = ProcessingManager(toast: ToastManager())
    @StateObject private var creditUIManager = CreditUIManager()
    @StateObject private var myLibraryVM = MyLibraryViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var navigationManager = NavigationManager.shared
    
    // Deep link state for notifications
    @State private var notificationDeepLinkTrigger = false
    @State private var pendingNotificationData: [String: Any]?
    
    // Scene phase for app state detection
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()

    init() {
        FirebaseApp.configure()
        configureAudioSession()
        configureRevenueCat()
        
        // Clear user cache on app startup to ensure fresh data (especially profile images)
        UserCache.shared.clearCacheOnAppStartup()
        
        // Set up notification observer
        setupNotificationObserver()
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .openCompletedIdea,
            object: nil,
            queue: .main
        ) { notification in
            // Cast the userInfo properly
            if let userInfo = notification.userInfo {
                let stringDict = Dictionary(uniqueKeysWithValues: 
                    userInfo.compactMap { key, value in
                        if let stringKey = key as? String {
                            return (stringKey, value)
                        }
                        return nil
                    }
                )
                pendingNotificationData = stringDict
                notificationDeepLinkTrigger.toggle()
            }
        }
    }
    
    private func configureRevenueCat() {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String else {
            fatalError("RevenueCat API key not found in Info.plist")
        }
        
        SubscriptionService.shared.configure(apiKey: apiKey)
        print("🟢 RevenueCat configured in DuetApp")
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ AVAudioSession error: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                AuthenticationView()
                    .environmentObject(authVM)
                    .environmentObject(groupsVM)
                    .environmentObject(toastManager)
                    .environmentObject(dateIdeaVM)
                    .environmentObject(activityVM)
                    .environmentObject(exploreVM)
                    .environmentObject(processingManager)
                    .environmentObject(creditUIManager)
                    .environmentObject(myLibraryVM)
                    .environmentObject(notificationManager)
                    .environmentObject(navigationManager)
                    .environmentObject(subscriptionService)
                    .environmentObject(subscriptionViewModel)
                    .onOpenURL(perform: handleInviteURL(_:))
                    .onAppear {
                        // Configure ProcessingManager with proper references
                        processingManager.updateToast(toastManager)
                        processingManager.updateAuthViewModel(authVM)
                        processingManager.updateMyLibraryViewModel(myLibraryVM)
                        
                        // Configure CreditService with UI manager
                        CreditService.shared.configure(with: creditUIManager)
                        
                        // Initialize WelcomeCreditService to fetch welcome credits once at startup
                        Task {
                            await WelcomeCreditService.shared.fetchWelcomeCreditsIfNeeded()
                        }
                        
                        // Request notification permissions
                        Task {
                            await notificationManager.requestNotificationPermission()
                        }
                        
                        // Force refresh current user data to ensure we have latest player_level
                        if authVM.state == .authenticated {
                            authVM.forceRefreshCurrentUser()
                            
                            // Initialize MyLibraryViewModel with current user
                            if let userId = authVM.user?.uid {
                                myLibraryVM.setAuthorId(userId)
                                myLibraryVM.backgroundLoadUserIdeas()
                            }
                        }
                    }
                    .onChange(of: notificationDeepLinkTrigger) { _ in
                        if let deepLinkData = pendingNotificationData {
                            handleNotificationDeepLink(deepLinkData)
                            pendingNotificationData = nil
                        }
                    }
                    .onChange(of: scenePhase) { newPhase in
                        handleScenePhaseChange(newPhase)
                    }
                    .sheet(isPresented: $subscriptionService.showPaywall) {
                        SubscriptionPaywallView()
                            .environmentObject(toastManager)
                            .environmentObject(subscriptionViewModel)
                            .onDisappear {
                                subscriptionService.dismissPaywall()
                            }
                    }
                
                if let result = groupsVM.joinResult {
                    ResultAlertView(result: result) {
                        groupsVM.joinResult = nil
                    }
                    .zIndex(1)
                }
            }
            .withAppTheme()
        }
    }
    
    private func handleInviteURL(_ url: URL) {
        guard url.scheme == "duet" else { return }
        
        if url.host == "join" {
            // Handle group invites
            guard let gid = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                              .queryItems?
                              .first(where: { $0.name == "groupId" })?
                              .value
            else { return }
            Task {
              await groupsVM.joinGroup(withId: gid)
            }
        } else if url.host == "share" {
            handleSharedUrl(from: url)
        } else if url.host == "payment-success" {
            handlePaymentSuccess()
        } else if url.host == "payment-cancel" {
            handlePaymentCancel()
        }
    }
    
    private func handleSharedUrl(from url: URL) {
        // Extract videoUrl from URL
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let videoUrl = urlComponents.queryItems?.first(where: { $0.name == "videoUrl" })?.value else {
            toastManager.error("No video URL found in share")
            return
        }
        
        // Check authentication
        if authVM.state == .authenticated {
            dateIdeaVM.urlText = videoUrl
            dateIdeaVM.summariseVideo()
        } else {
            toastManager.error("You must be signed in to process shared videos.")
        }
    }
    
    private func handlePaymentSuccess() {
        // Show success toast
        toastManager.success("🎉 Payment successful! Credits added to your account.")
        
        // Refresh credit balance and history to show new credits
        Task {
            await CreditService.shared.refreshCreditData()
        }
        
        // Force refresh current user data to ensure latest credits and player level
        if authVM.state == .authenticated {
            authVM.forceRefreshCurrentUser()
        }
        
        // Hide any open credit-related sheets
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            creditUIManager.dismissAllSheets()
        }
    }
    
    private func handlePaymentCancel() {
        // Show informational toast (not an error since user chose to cancel)
        toastManager.error("Payment cancelled. You can try again anytime.")
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active - clear any delivered notifications
            notificationManager.clearAllDeliveredNotifications()
            notificationManager.clearBadge()
            print("📱 App became active - cleared notifications")
            
        case .inactive:
            print("📱 App became inactive")
            
        case .background:
            print("📱 App entered background")
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Notification Deep Linking
    
    private func handleNotificationDeepLink(_ userInfo: [String: Any]) {
        guard authVM.state == .authenticated,
              let ideaId = userInfo["ideaId"] as? String else {
            print("❌ Cannot handle notification deep link - not authenticated or missing ideaId")
            return
        }
        
        let groupId = userInfo["groupId"] as? String
        
        // Clear any delivered notifications since user is now in the app
        notificationManager.clearAllDeliveredNotifications()
        
        // Use NavigationManager to handle the deep link
        navigationManager.navigateToIdea(ideaId: ideaId, groupId: groupId)
        
        // Show success toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            toastManager.success("✨ Opening your completed idea!")
        }
        
        print("🧭 DuetApp: Initiated navigation to idea \(ideaId)")
    }
}
