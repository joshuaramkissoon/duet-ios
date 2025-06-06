import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var authVM: AuthenticationViewModel
    @EnvironmentObject private var toast: ToastManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("defaultPublishIdeas") private var publishIdeasEnabled = false // Changed to use UserDefaults and default to false
    
    // Delete account confirmation states
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    
    // Blocked users state
    @State private var blockedUsersCount = 0
    @State private var showingBlockedUsers = false
    
    var body: some View {
        List {
            // MARK: - Notifications Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Idea Notifications", isOn: $notificationsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
                    
                    Text(notificationsEnabled ? 
                         "Turn off to stop receiving notifications. You can also disable in iOS Settings." :
                         "Turn on to receive notifications about new ideas and updates. You can also manage this in iOS Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Notifications")
            }
            
            // MARK: - Privacy Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Publish Ideas", isOn: $publishIdeasEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
                    
                    Text(publishIdeasEnabled ? 
                         "New ideas will be public by default and visible to other users." :
                         "New ideas will be private by default. You can still make individual ideas public later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Privacy")
            }
            
            // MARK: - Blocked Users Section (only show if there are blocked users)
            if blockedUsersCount > 0 {
                Section {
                    Button(action: {
                        showingBlockedUsers = true
                    }) {
                        HStack(spacing: 12) {
                            // Beautiful icon with gradient
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.15), Color.orange.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "person.slash.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.8), Color.orange.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Blocked Users")
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                
                                Text("Manage users you've blocked")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Beautiful count badge
                            HStack(spacing: 8) {
                                Text("\(blockedUsersCount)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.red.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Content Moderation")
                }
            }
            
            // MARK: - Legal Section
            Section {
                Button(action: {
                    showingTermsOfService = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.appPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Terms of Service")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            
                            Text("View our terms and conditions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                Button(action: {
                    showingPrivacyPolicy = true
                }) {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(.appAccent)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Policy")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            
                            Text("How we handle your data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Legal")
            }
            
            // MARK: - Account Section
            Section {
                Button(action: {
                    authVM.signOut()
                }) {
                    HStack {
                        Image(systemName: "arrow.backward.circle")
                            .foregroundColor(.appPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign Out")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            
                            Text("Sign out of your account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
                
                Button(action: {
                    showDeleteAccountAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Account")
                                .foregroundColor(.red.opacity(0.8))
                                .fontWeight(.medium)
                            
                            Text("Permanently delete your account and all data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isDeletingAccount {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isDeletingAccount)
                .padding(.vertical, 4)
            } header: {
                Text("Account")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView(isPresented: $showingTermsOfService)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView(isPresented: $showingPrivacyPolicy)
        }
        .sheet(isPresented: $showingBlockedUsers) {
            BlockedUsersView()
                .environmentObject(toast)
        }
        .onAppear {
            loadBlockedUsersCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userBlocked)) { _ in
            loadBlockedUsersCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userUnblocked)) { _ in
            loadBlockedUsersCount()
        }
        .onChange(of: notificationsEnabled) { _, newValue in
            // Handle notification permission when toggle changes
            if newValue {
                checkNotificationPermission()
            }
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied {
                    // Could show an alert here to guide user to iOS Settings
                    // For now, we'll just respect the app setting
                }
            }
        }
    }
    
    private func deleteAccount() async {
        isDeletingAccount = true
        
        do {
            try await authVM.deleteAccount()
            // Account deletion successful - user is automatically signed out
            // and state is reset in AuthenticationViewModel
        } catch {
            isDeletingAccount = false
            toast.error("Failed to delete account: \(error.localizedDescription)")
        }
    }
    
    private func loadBlockedUsersCount() {
        ContentModerationService.shared.getBlockedUsers { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let blockedUserIds):
                    self.blockedUsersCount = blockedUserIds.count
                case .failure:
                    self.blockedUsersCount = 0
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AuthenticationViewModel())
            .environmentObject(ToastManager())
    }
} 
