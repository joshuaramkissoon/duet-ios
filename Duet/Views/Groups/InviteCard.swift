//
//  InviteCard.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteQRView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toast: ToastManager
    
    let url: URL
    let group: DuetGroup
    
    // For QR code generation
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        VStack(spacing: 0) {
            
            // QR Code
            VStack(spacing: 16) {
                ZStack {
                    // QR Code container
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .frame(width: 240, height: 240)
                        .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 4)
                    
                    // QR Code itself
                    if let qrImage = generateQRCode(from: url.absoluteString) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 180, height: 180)
                    } else {
                        // Fallback if QR generation fails
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                    
                    // App icon overlay
                    GroupIcon(group: group, diam: 60, fontSize: 24)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .overlay(
                            GroupIcon(group: group, diam: 60, fontSize: 24)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                Text("Scan this code to join \(group.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 32)
            
            // URL Display & Sharing
            VStack(spacing: 8) {
                Text("Or share this link")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 0) {
                    Button(action: {
                        UIPasteboard.general.string = url.absoluteString
                        toast.success("Copied to clipboard")
                    }) {
                        Text(url.absoluteString)
                            .font(.system(.footnote, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundColor(.primary)
                    
                    // Share button
                    ShareLink(
                        item: url,
                        message: Text("Join my group in Duet!")) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.appPrimary)
                                .cornerRadius(12)
                    }
                    .padding(5)
                }
                .background(Color.gray.opacity(0.09))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .toast($toast.state)
        .withAppBackground()
    }
    
    // Generate QR Code with proper logo overlay
    private func generateQRCode(from string: String) -> UIImage? {
        // Create data from string
        guard let data = string.data(using: .utf8) else { return nil }
        
        // Set up filter
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // Higher correction level to accommodate logo
        
        // Get output image
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up the image for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        // Create CGImage
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        // Create UIImage with proper interpolation
        let uiImage = UIImage(cgImage: cgImage)
        
        return uiImage
    }
    
    // Present share sheet
    private func presentShareSheet(with url: URL) {
        let items: [Any] = [
            "Join me in \(group.name) on Duet: ",
            url
        ]
        guard let windowScene = UIApplication.shared
                .connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene
                .windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        else {
            return
        }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        root.present(activityVC, animated: true)
    }
}

#Preview {
    InviteQRView(url: URL(string: "duet://join?groupId=VjVIZwgWjoWTpDfUJaZi")!, group: DuetGroup(name: "Group name", ownerId: "", members: []))
}
