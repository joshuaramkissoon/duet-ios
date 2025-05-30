import SwiftUI
import Lottie

struct GroupURLInputView: View {
    let processingManager: ProcessingManager
    let groupId: String
    var showCardBackground: Bool = true
    
    @EnvironmentObject private var toast: ToastManager
    @State private var urlText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var didPaste = false
    
    var body: some View {
        Group {
            if showCardBackground {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    content
                }
            } else {
                content
            }
        }
        .frame(width: calculatedWidth)
    }
    
    private var content: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .trailing) {
                TextField("Enter video URL", text: $urlText)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(height: 30)
                    .padding(.vertical, 12)
                    .padding(.trailing, 48)
                    .padding(.leading, 16)
                    .focused($isTextFieldFocused)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button {
                    HapticFeedbacks.soft()
                    if let clip = UIPasteboard.general.string, !clip.isEmpty {
                        urlText = clip
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
            
            if !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    addVideoToGroup()
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "person.3.fill")
                        Text("Add to Group")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding()
                    .foregroundColor(urlText.isEmpty ? .gray : .white)
                    .background(urlText.isEmpty ? Color.appBackground : Color.appPrimary)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .disabled(urlText.isEmpty)
                .opacity(urlText.isEmpty ? 0.6 : 1.0)
            }
        }
    }
    
    private func addVideoToGroup() {
        // Validate URL input
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let _ = URL(string: trimmed) else {
            toast.error("Please enter a valid URL")
            return
        }
        
        // Format URL if needed
        let formattedUrl = formatUrl(trimmed)
        
        // Clear input
        urlText = ""
        isTextFieldFocused = false
        
        // Use ProcessingManager for group video processing
        Task {
            do {
                let response = try await processingManager.processVideoForGroup(url: formattedUrl, groupId: groupId)
                await MainActor.run {
                    toast.success(response.message ?? "Video processing started for group")
                }
            } catch {
                await MainActor.run {
                    if let processingError = error as? ProcessingError {
                        toast.error(processingError.localizedDescription)
                    } else {
                        toast.error("Failed to start video processing")
                    }
                }
            }
        }
    }
    
    private func formatUrl(_ urlString: String) -> String {
        if !urlString.lowercased().hasPrefix("http") {
            return "https://\(urlString)"
        }
        return urlString
    }
    
    // Dynamic width depending on context
    private var calculatedWidth: CGFloat {
        let screen = UIScreen.main.bounds.width
        if showCardBackground {
            return min(screen - 48, 360) // original behaviour
        } else {
            return min(screen - 24, 420) // use extra space when embedded in card
        }
    }
}

#Preview {
    GroupURLInputView(
        processingManager: ProcessingManager(toast: ToastManager()),
        groupId: "test-group"
    )
    .environmentObject(ToastManager())
    .padding()
} 
