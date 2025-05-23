//
//  JoinSuccessView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import Lottie

enum AlertResult: Equatable {
    case success(title: String, message: String?)
    case failure(title: String, message: String?)
    
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}

struct ResultAlertView: View {
    let result: AlertResult
    let onDismiss: () -> Void

    @State private var startedDismissTimer = false
    @State private var showContent = false
    private let autoDismissDelay: TimeInterval = 4.0

    private var title: String {
        switch result {
        case .success(let title, _), .failure(let title, _):
            return title
        }
    }

    private var message: String? {
        switch result {
        case .success(_, let message), .failure(_, let message):
            return message
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if result.isSuccess {
            LottieView(animation: .named("duet-success"))
                .playing(loopMode: .playOnce)
                .frame(width: 40, height: 40)
        }
        else {
            // Fallback to error img
            Image(systemName: "x.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.red)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.8))
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .offset(y: showContent ? 0 : UIScreen.main.bounds.height)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showContent)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            guard !startedDismissTimer else { return }
            startedDismissTimer = true
            // animate in
            showContent = true
            // auto dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
                // animate out
                showContent = false
                // delay actual dismiss to allow animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onDismiss()
                }
            }
        }
    }
}


#Preview {
    ResultAlertView(result: .success(title: "Success", message: "This is a success message."), onDismiss: {
        
    })
    ResultAlertView(result: .failure(title: "Oops!", message: "This is an error message."), onDismiss: {
        
    })
}
