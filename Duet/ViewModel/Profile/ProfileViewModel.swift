//
//  ProfileViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import UIKit

class ProfileViewModel: ObservableObject {
    @Published var qrImage: UIImage?
    @Published var isSharing: Bool = false
    
    // Profile image upload states
    @Published var selectedImageItem: PhotosPickerItem?
    @Published var profileImage: UIImage?
    @Published var selectedUIImage: UIImage? // For immediate display before upload completes
    
    // Reference to AuthViewModel for refreshing user data
    weak var authViewModel: AuthenticationViewModel?
    // Reference to ToastManager for upload feedback
    weak var toastManager: ToastManager?

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    /// Generate a QR code image from the given string
    func generateQRCode(from string: String) {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        guard let output = filter.outputImage else {
            qrImage = nil
            return
        }
        // Scale up for clarity
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = output.transformed(by: transform)

        if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
            qrImage = UIImage(cgImage: cgimg)
        }
    }

    /// Trigger the share sheet
    func share() {
        isSharing = true
    }
    
    // MARK: - Profile Image Upload
    
    /// Called when user selects image from PhotosPicker
    func handleImageSelection() {
        guard let selectedImageItem = selectedImageItem else { return }
        
        Task {
            do {
                if let data = try await selectedImageItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    await MainActor.run {
                        // Show image immediately for instant feedback
                        self.selectedUIImage = uiImage
                        self.profileImage = uiImage
                    }
                    
                    // Start upload process in background (no loading UI)
                    await uploadProfileImageInBackground(uiImage)
                }
            } catch {
                await MainActor.run {
                    self.toastManager?.error("Failed to load selected image")
                    print("❌ Error loading image: \(error)")
                }
            }
        }
    }
    
    /// Upload the profile image to backend in background
    @MainActor
    private func uploadProfileImageInBackground(_ image: UIImage) async {
        // Resize and compress image
        guard let resizedImage = resizeImage(image, to: CGSize(width: 400, height: 400)),
              let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            toastManager?.error("Failed to process image")
            selectedUIImage = nil // Clear the immediate image on failure
            return
        }
        
        NetworkClient.shared.uploadProfileImage(imageData: imageData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedUser):
                    print("🟢 Profile image uploaded successfully: \(updatedUser.profileImageUrl ?? "no URL")")
                    self?.toastManager?.success("Profile image updated!")
                    
                    // Keep selectedUIImage to avoid flicker - remote URL will be used on next app launch
                    // Don't clear selectedUIImage here to prevent brief initials flash
                    
                    // Immediately update authVM.currentUser (no network call needed)
                    self?.authViewModel?.currentUser = updatedUser
                    
                    // Send notification to update all cached user instances across the app
                    NotificationCenter.default.post(
                        name: .userProfileUpdated,
                        object: nil,
                        userInfo: ["updatedUser": updatedUser]
                    )
                    
                case .failure(let error):
                    self?.toastManager?.error("Upload failed: \(error.localizedDescription)")
                    print("❌ Profile image upload failed: \(error)")
                    // Clear the immediate image on failure so user can retry
                    self?.selectedUIImage = nil
                }
            }
        }
    }
    
    /// Resize image while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
}
