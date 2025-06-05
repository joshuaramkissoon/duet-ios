import SwiftUI

struct OperationalControlsSection: View {
    @Binding var isExpanded: Bool
    let dateIdea: DateIdeaResponse
    let groupId: String?
    let canEdit: Bool
    @ObservedObject var viewModel: DateIdeaViewModel
    let onShareToGroup: () -> Void
    let onImproveWithAI: () -> Void
    
    private var footerText: String {
        if canEdit {
            return "Visibility, sharing & more"
        } else {
            return "Sharing & more"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header button (always visible) - entire area clickable
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundColor(.appPrimary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Options")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(isExpanded ? "Manage this idea" : footerText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicators (when collapsed)
                if !isExpanded {
                    HStack(spacing: 8) {
                        // Visibility indicator for personal ideas (only if user can edit)
                        if groupId == nil && canEdit {
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
                    }
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle()) // Makes entire area clickable
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
            
            // Expanded content with proper animation
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 12) {
                        // Visibility Section (only for personal ideas and if user can edit)
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
                        
                        // Share to Group - consistent layout
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
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.appSecondaryLightBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.appSecondary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Conditional options based on edit permissions
                        if canEdit {
                            // Improve with AI - for owners only
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
                                            
                                            // Coming soon pill
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
                                        
                                        Text("Chat about this idea and enhance details")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.gray.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(true)
                            .buttonStyle(.plain)
                        } else {
                            // Save to Library - for non-owners
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
                                            
                                            // Coming soon pill
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
                                        
                                        Text("Save this idea to your personal library")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.gray.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(true)
                            .buttonStyle(.plain)
                        }
                        
                        // Future operational controls can be added here
                        // For example: Download for offline, Report content, etc.
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .background(
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
        )
    }
}