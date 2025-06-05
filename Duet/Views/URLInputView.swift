//
//  URLInputView.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI
import Lottie

struct URLInputView: View {
    @ObservedObject var viewModel: DateIdeaViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var didPaste = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image("duet-landing")
              .resizable()
              .scaledToFit()
              .clipShape(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
              )
              .padding(.horizontal, 40)
              .padding(.top, 20)

            
            Text("Save your ideas!")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Paste any video URL to generate a new idea")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 0) {
                    ZStack(alignment: .trailing) {
                        TextField("Enter URL", text: $viewModel.urlText)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(height: 30)
                            .padding(.vertical, 12)
                            .padding(.trailing, 48)
                            .padding(.leading)
                            .focused($isTextFieldFocused)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button {
                            HapticFeedbacks.soft()
                            if let clip = UIPasteboard.general.string, !clip.isEmpty {
                                viewModel.urlText = clip
                                // show checkmark animation
                                didPaste = true
                            }
                        } label: {
                            if didPaste {
                                LottieView(animation: .named("duet-success"))
                                    .playing()
                                    .animationDidFinish { finished in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            didPaste = false
                                        }
                                    }
                                    .frame(width: 35, height: 35)
                            }
                            else {
                                Image(systemName: "clipboard.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.appPrimary)
                            }
                        }
                        .padding(.trailing, 12)
                    }
                    
                    if !viewModel.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                        
                        Button(action: {
                            viewModel.summariseVideo()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "sparkles")
                                Text("Analyse")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding()
                            .foregroundColor(viewModel.urlText.isEmpty ? .gray : .white)
                            .background(viewModel.urlText.isEmpty ? Color.appBackground : Color.appPrimary)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .disabled(viewModel.urlText.isEmpty)
                        .opacity(viewModel.urlText.isEmpty ? 0.6 : 1.0)
                    }
                }
            }
            .frame(width: min(UIScreen.main.bounds.width - 48, 360))
            // let the inner content size itself vertically
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    URLInputView(viewModel: DateIdeaViewModel(toast: ToastManager()))
}
