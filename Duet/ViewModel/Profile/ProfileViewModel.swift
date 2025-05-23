//
//  ProfileViewModel.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/05/2025.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class ProfileViewModel: ObservableObject {
    @Published var qrImage: UIImage?
    @Published var isSharing: Bool = false

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
}
