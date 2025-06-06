//
//  Toast.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import UIKit

/// Represents either a success or error toast, carrying its message.
enum ToastState: Equatable {
    case success(message: String)
    case error(message: String)
    case loading(message: String)          // ⬅️ NEW

    /// SF Symbol to show (nil → use spinner)
    var iconName: String? {
        switch self {
        case .success:         return "checkmark.circle"
        case .error:           return "xmark.octagon"
        case .loading:         return nil                  // spinner instead
        }
    }

    /// Tint for the icon / spinner
    var iconColor: Color {
        switch self {
        case .success:         return .green.opacity(0.7)
        case .error:           return .red.opacity(0.7)
        case .loading:         return .primary.opacity(0.8)
        }
    }

    /// Display text
    var message: String {
        switch self {
        case let .success(msg), let .error(msg), let .loading(msg):
            return msg
        }
    }

    /// Should this toast dismiss itself?
    var autoDismissAfter: TimeInterval? {
        switch self {
        case .success: return 2
        case .error:   return 2
        case .loading: return nil
        }
    }
}

struct ToastView: View {
    let state: ToastState
    
    var body: some View {
        HStack(spacing: 8) {
            // Either an SF Symbol or a `ProgressView`
            if let icon = state.iconName {
                Image(systemName: icon)
                    .foregroundColor(state.iconColor)
                    .font(.headline)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(state.iconColor)
            }

            Text(state.message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.adaptiveCardBackground.opacity(0.95))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastState?
    
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast {
                ToastView(state: toast)
                    .padding(.horizontal)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: toast) { _, newValue in
            guard let newValue = newValue else { return }
            HapticFeedbacks.soft()
            if let delay = toast?.autoDismissAfter {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation { toast = nil }
                }
            }
        }
        .animation(.spring(), value: toast != nil)
    }
}

extension View {
    /// Attach a toast to any view
    func toast(_ binding: Binding<ToastState?>) -> some View {
        self.modifier(ToastModifier(toast: binding))
    }
}


#Preview {
    ToastView(state: .success(message: "Great success"))
}
