//
//  ReportContentView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import SwiftUI

struct ReportContentView: View {
    let ideaId: String
    @Binding var isPresented: Bool
    @EnvironmentObject private var toast: ToastManager
    
    @State private var selectedReason: ContentReportReason?
    @State private var customReason: String = ""
    @State private var description: String = ""
    @State private var isSubmitting: Bool = false
    
    private var isFormValid: Bool {
        guard let reason = selectedReason else { return false }
        
        // If "Other" is selected, require custom reason
        if reason == .other && customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        
        // Description is always required
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.adaptiveBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header with beautiful icon
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.8), Color.red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 8) {
                                Text("Report Content")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Help us maintain a safe and respectful community by reporting content that violates our guidelines.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.top, 24)
                        
                        // Reason Selection - Beautiful cards
                        VStack(alignment: .leading, spacing: 20) {
                            Text("What's the issue?")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 12) {
                                ForEach(ContentReportReason.allCases, id: \.self) { reason in
                                    BeautifulReportReasonCard(
                                        reason: reason,
                                        isSelected: selectedReason == reason,
                                        onTap: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedReason = reason
                                                // Clear custom reason if not "Other"
                                                if reason != .other {
                                                    customReason = ""
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Custom Reason (shown only when "Other" is selected)
                        if selectedReason == .other {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Please specify")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.leading, 4)
                                
                                TextField("Enter specific reason...", text: $customReason, axis: .vertical)
                                    .lineLimit(2...4)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.adaptiveCardBackground)
                                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                    )
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            ))
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional Details")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .padding(.leading, 4)
                            
                            Text("Please provide specific details about the issue to help our team review this content.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            TextField("Describe what you found inappropriate...", text: $description, axis: .vertical)
                                .lineLimit(4...8)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.adaptiveCardBackground)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                )
                        }
                        
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .fontWeight(.semibold)
                    .foregroundColor(isFormValid && !isSubmitting ? .red : .secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                beautifulSubmitButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .background(
                        Color.adaptiveBackground
                            .ignoresSafeArea()
                    )
            }
        }
        .toast($toast.state)
    }
    
    private var beautifulSubmitButton: some View {
        Button(action: submitReport) {
            HStack(spacing: 12) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    
                    Text("Submitting Report...")
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Submit Report")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isFormValid && !isSubmitting {
                        LinearGradient(
                            colors: [Color.red.opacity(0.8), Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: isFormValid && !isSubmitting ? Color.red.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(!isFormValid || isSubmitting)
        .scaleEffect(isFormValid && !isSubmitting ? 1.0 : 0.98)
        .animation(.easeInOut(duration: 0.2), value: isFormValid)
    }
    
    private func submitReport() {
        guard let reason = selectedReason, isFormValid else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isSubmitting = true
        }
        
        // Use custom reason if "Other" is selected, otherwise use the display name
        let finalReason = reason == .other ? customReason.trimmingCharacters(in: .whitespacesAndNewlines) : reason.displayName
        let finalDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        ContentModerationService.shared.reportContent(
            ideaId: ideaId,
            reason: reason,
            description: "\(finalReason): \(finalDescription)"
        ) { result in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSubmitting = false
                }
                
                switch result {
                case .success:
                    toast.success("Report submitted successfully. Thank you for helping keep our community safe.")
                    isPresented = false
                    
                case .failure(let error):
                    toast.error("Failed to submit report: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Beautiful Report Reason Card

struct BeautifulReportReasonCard: View {
    let reason: ContentReportReason
    let isSelected: Bool
    let onTap: () -> Void
    
    private var iconName: String {
        switch reason {
        case .inappropriateContent:
            return "exclamationmark.triangle.fill"
        case .spam:
            return "envelope.badge.fill"
        case .harassment:
            return "person.2.badge.minus"
        case .copyright:
            return "c.circle.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
    
    private var accentColor: Color {
        switch reason {
        case .inappropriateContent:
            return .red
        case .spam:
            return .orange
        case .harassment:
            return .purple
        case .copyright:
            return .blue
        case .other:
            return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Beautiful icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected ? [accentColor.opacity(0.2), accentColor.opacity(0.1)] : [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? accentColor : .secondary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(reason.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.adaptiveCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected ? accentColor.opacity(0.5) : Color.gray.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? accentColor.opacity(0.1) : Color.black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Content Report Reason Extensions

extension ContentReportReason {
    var description: String {
        switch self {
        case .inappropriateContent:
            return "Content that violates community guidelines"
        case .spam:
            return "Repetitive, unsolicited, or promotional content"
        case .harassment:
            return "Bullying, threats, or harmful behavior"
        case .copyright:
            return "Unauthorized use of copyrighted material"
        case .other:
            return "Other issues not covered above"
        }
    }
}

#Preview {
    ReportContentView(ideaId: "test-idea-id", isPresented: .constant(true))
        .environmentObject(ToastManager())
} 