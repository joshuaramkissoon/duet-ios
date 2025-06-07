//
//  Image.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//

import SwiftUI

struct Base64ImageView: View {
    let base64String: String

    var thumbWidth: CGFloat = 140
    var thumbHeight: CGFloat? = nil
    
    private var calculatedHeight: CGFloat {
        thumbHeight ?? (thumbWidth * 16/9)  // Default to 9:16 if no height provided
    }

    var body: some View {
        Group {
            if let data = Data(base64Encoded: base64String),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // placeholder
                Color.gray
            }
        }
        .frame(width: thumbWidth, height: calculatedHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
    }
}

struct PlaceholderImageView: View {
    var thumbWidth: CGFloat = 140
    var thumbHeight: CGFloat? = nil
    
    private var calculatedHeight: CGFloat {
        thumbHeight ?? (thumbWidth * 16/9)  // Default to 9:16 if no height provided
    }

    var body: some View {
        Group {
            Color.gray
        }
        .frame(width: thumbWidth, height: calculatedHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
    }
}

struct RemoteImageView: View {
    let urlString: String

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .empty:
                // Placeholder while loading
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let image):
                // Successfully loaded image
                image
                    .resizable()
                    .scaledToFill()
                    .clipped()
            case .failure:
                // Error placeholder
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 200, height: 200)   // adjust as needed
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

#Preview {
    let testBase64Image = """
    iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2P8z/C/HwAGgwJ/lxQh8QAAAABJRU5ErkJggg==
    """
    Base64ImageView(base64String: testBase64Image)
}
