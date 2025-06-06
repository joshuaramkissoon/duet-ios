import SwiftUI
import FirebaseAuth

struct OperationalControlsSection: View {
    @Binding var isExpanded: Bool
    let dateIdea: DateIdeaResponse
    let groupId: String?
    let canEdit: Bool
    @ObservedObject var viewModel: DateIdeaViewModel
    let onShareToGroup: () -> Void
    let onImproveWithAI: () -> Void
    
    // Content moderation state
    @State private var showingReportContent = false
    @State private var showingBlockUser = false
    @State private var authorUser: User?
    @EnvironmentObject private var toast: ToastManager
    
    private var footerText: String {
        if canEdit {
            return "Visibility, sharing & more"
        } else {
            return "Sharing & more"
        }
    }
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var isViewingOtherUsersContent: Bool {
        guard let currentUserId = currentUserId,
              let contentUserId = dateIdea.user_id else {
            return false
        }
        return currentUserId != contentUserId
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            headerIcon
            headerContent
            Spacer()
            statusIndicators
            chevronIcon
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    @ViewBuilder
    private var headerIcon: some View {
        Image(systemName: "slider.horizontal.3")
            .font(.system(size: 20))
            .foregroundColor(.appPrimary)
            .frame(width: 24, height: 24)
    }
    
    @ViewBuilder
    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Options")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(isExpanded ? "Manage this idea" : footerText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var statusIndicators: some View {
        if !isExpanded {
            HStack(spacing: 8) {
                if groupId == nil && canEdit {
                    visibilityIndicator
                }
            }
        }
    }
    
    @ViewBuilder
    private var visibilityIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: dateIdea.isPublic ? "globe" : "lock.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(dateIdea.isPublic ? .appAccent : .appPrimary)
            
            Text(dateIdea.isPublic ? "Public" : "Private")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(dateIdea.isPublic ? .appAccent : .appPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(dateIdea.isPublic ? Color.appAccentLightBackground : Color.appPrimaryLightBackground)
        )
    }
    
    @ViewBuilder
    private var chevronIcon: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
    }
    
    // MARK: - Expanded Content
    
    @ViewBuilder
    private var expandedContent: some View {
        if isExpanded {
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 12) {
                    visibilitySection
                    shareToGroupButton
                    conditionalOptions
                    contentModerationSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        }
    }
    
    @ViewBuilder
    private var visibilitySection: some View {
        if groupId == nil && canEdit {
            VisibilityToggleCard(
                isPublic: dateIdea.isPublic,
                isUpdating: viewModel.isUpdatingVisibility,
                onToggle: { newVisibility in
                    viewModel.updateVisibility(
                        ideaId: dateIdea.id,
                        isPublic: newVisibility,
                        groupId: groupId
                    )
                }
            )
        }
    }
    
    @ViewBuilder
    private var shareToGroupButton: some View {
        Button(action: onShareToGroup) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(.appSecondary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share to Group")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Add this idea to one of your groups")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(shareToGroupBackground)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var shareToGroupBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.appSecondaryLightBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.appSecondary.opacity(0.3), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var conditionalOptions: some View {
        if canEdit {
            improveWithAIButton
        } else {
            saveToLibraryButton
        }
    }
    
    @ViewBuilder
    private var improveWithAIButton: some View {
        Button(action: onImproveWithAI) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Improve with AI")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        comingSoonPill
                    }
                    
                    Text("Chat about this idea and enhance details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(disabledButtonBackground)
        }
        .disabled(true)
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var saveToLibraryButton: some View {
        Button(action: {
            // Disabled for now
        }) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Save to Library")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        comingSoonPill
                    }
                    
                    Text("Save this idea to your personal library")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(disabledButtonBackground)
        }
        .disabled(true)
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var comingSoonPill: some View {
        Text("Coming Soon")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.orange.opacity(0.15))
            )
    }
    
    @ViewBuilder
    private var disabledButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var contentModerationSection: some View {
        if isViewingOtherUsersContent {
            VStack(spacing: 12) {
                moderationDivider
                reportContentButton
                blockUserButton
            }
        }
    }
    
    @ViewBuilder
    private var moderationDivider: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Text("Community Safety")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 12)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var reportContentButton: some View {
        Button(action: {
            showingReportContent = true
        }) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Report Content")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Report inappropriate or harmful content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(reportButtonBackground)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var reportButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.orange.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var blockUserButton: some View {
        Button(action: {
            fetchAuthorAndShowBlockDialog()
        }) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "person.slash")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Block User")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Hide all content from this user")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(blockButtonBackground)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var blockButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.red.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
    }
    
    // MARK: - Main Body
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            expandedContent
        }
        .background(mainBackground)
        .sheet(isPresented: $showingReportContent) {
            ReportContentView(ideaId: dateIdea.id, isPresented: $showingReportContent)
                .environmentObject(toast)
        }
        .sheet(isPresented: $showingBlockUser) {
            if let user = authorUser {
                BlockUserView(user: user, isPresented: $showingBlockUser)
                    .environmentObject(toast)
            }
        }
    }
    
    @ViewBuilder
    private var mainBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(
                color: Color.black.opacity(0.06),
                radius: isExpanded ? 12 : 6,
                x: 0,
                y: isExpanded ? 6 : 3
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
            )
    }
    
    private func fetchAuthorAndShowBlockDialog() {
        guard let userId = dateIdea.user_id else {
            toast.error("Unable to block user: User information not available")
            return
        }
        
        // Check if we already have the author user
        if let author = authorUser, author.id == userId {
            showingBlockUser = true
            return
        }
        
        // Fetch the author user information
        NetworkClient.shared.getUsers(with: [userId]) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let users):
                    if let user = users.first {
                        authorUser = user
                        showingBlockUser = true
                    } else {
                        toast.error("Unable to block user: User information not found")
                    }
                case .failure(let error):
                    toast.error("Unable to block user: \(error.localizedDescription)")
                }
            }
        }
    }
}