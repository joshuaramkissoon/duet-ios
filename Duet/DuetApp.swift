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
    @StateObject private var authVM = AuthenticationViewModel()
    @StateObject private var groupsVM = GroupsViewModel()
    @StateObject private var toastManager = ToastManager()

    init() {
        FirebaseApp.configure()
        configureAudioSession()
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
                    .onOpenURL(perform: handleInviteURL(_:))
                
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
        guard url.scheme == "duet",
              url.host == "join",
              let gid = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                          .queryItems?
                          .first(where: { $0.name == "groupId" })?
                          .value
        else { return }
        Task {
          await groupsVM.joinGroup(withId: gid)
        }
    }
}
