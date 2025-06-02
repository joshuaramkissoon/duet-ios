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

    init() {
        FirebaseApp.configure()
        configureAudioSession()
        
        // Clear user cache on app startup to ensure fresh data (especially profile images)
        UserCache.shared.clearCacheOnAppStartup()
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
                    .onOpenURL(perform: handleInviteURL(_:))
                    .onAppear {
                        // Configure ProcessingManager with proper references
                        processingManager.updateToast(toastManager)
                        
                        // Configure CreditService with UI manager
                        CreditService.shared.configure(with: creditUIManager)
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
        
        // Hide any open credit-related sheets
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            creditUIManager.dismissAllSheets()
        }
    }
    
    private func handlePaymentCancel() {
        // Show informational toast (not an error since user chose to cancel)
        toastManager.error("Payment cancelled. You can try again anytime.")
    }
}
