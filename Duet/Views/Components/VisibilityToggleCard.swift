import SwiftUI

struct VisibilityToggleCard: View {
    let isPublic: Bool
    let isUpdating: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isPublic)
        }) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isPublic ? "globe" : "lock.fill")
                    .font(.title2)
                    .foregroundColor(isPublic ? .appAccent : .appPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isPublic ? "Public Idea" : "Private Idea")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(isPublic ? 
                         "Visible to all users on Duet" : 
                         "Only visible to you")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Toggle("", isOn: .constant(isPublic))
                        .toggleStyle(SwitchToggleStyle(tint: isPublic ? .appAccent : .appPrimary))
                        .disabled(true) // Visual only - interaction handled by button
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isPublic ? Color.appAccentLightBackground : Color.appPrimaryLightBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isPublic ? Color.appAccent.opacity(0.3) : Color.appPrimary.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
    }
}

#Preview {
    VStack(spacing: 16) {
        VisibilityToggleCard(
            isPublic: true,
            isUpdating: false,
            onToggle: { _ in }
        )
        
        VisibilityToggleCard(
            isPublic: false,
            isUpdating: false,
            onToggle: { _ in }
        )
        
        VisibilityToggleCard(
            isPublic: true,
            isUpdating: true,
            onToggle: { _ in }
        )
    }
    .padding()
} 