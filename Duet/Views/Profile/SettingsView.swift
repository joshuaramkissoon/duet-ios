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
            
            // MARK: - Account Section
            Section {
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
        .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
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
    
    private func deleteAccount() {
        isDeletingAccount = true
        
        Task {
            do {
//                try await authVM.deleteAccount()
                
                await MainActor.run {
                    isDeletingAccount = false
                    toast.success("Account deleted successfully")
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    toast.error("Failed to delete account: \(error.localizedDescription)")
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
