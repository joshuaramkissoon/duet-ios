import SwiftUI

struct VideoAuthorAttribution: View {
    let authorHandle: String
    let authorUrl: String
    let originalSourceUrl: String?
    let platform: String
    var onAuthorTap: (URL) -> Void
    var onSourceTap: (URL) -> Void
    
    private var iconAndColor: (icon: String, color: Color, isSystem: Bool) {
        switch platform.lowercased() {
        case "tiktok":
            return ("tiktok-icon", .pink, false)
        case "instagram", "insta":
            return ("insta-icon", .purple, false)
        case "youtube":
            return ("youtube-icon", .red, false)
        default:
            return ("link", .gray, true)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            
            // Author button
            Button(action: {
                if let url = URL(string: authorUrl) {
                    onAuthorTap(url)
                }
            }) {
                HStack(spacing: 6) {
                    if iconAndColor.isSystem {
                        Image(systemName: iconAndColor.icon)
                            .foregroundColor(iconAndColor.color)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(iconAndColor.icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(iconAndColor.color)
                    }
                    Text(authorHandle)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(Color.secondary)
                }
            }
            
            // Dot separator and source link (only show if originalSourceUrl exists)
            if let originalSourceUrl = originalSourceUrl, !originalSourceUrl.isEmpty {
                Text("•")
                    .font(.footnote)
                    .foregroundColor(Color.secondary.opacity(0.6))
                
                Button(action: {
                    if let url = URL(string: originalSourceUrl) {
                        onSourceTap(url)
                    }
                }) {
                    Image(systemName: "link")
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        VideoAuthorAttribution(
            authorHandle: "@timwoo12",
            authorUrl: "https://www.tiktok.com/@timwoo12",
            originalSourceUrl: "https://www.tiktok.com/@timwoo12/video/1234567890",
            platform: "tiktok"
        ) { url in
            print("Opening author: \(url)")
        } onSourceTap: { url in
            print("Opening source: \(url)")
        }
        
        VideoAuthorAttribution(
            authorHandle: "@johndoe",
            authorUrl: "https://www.instagram.com/johndoe",
            originalSourceUrl: "https://www.instagram.com/p/ABC123/",
            platform: "instagram"
        ) { url in
            print("Opening author: \(url)")
        } onSourceTap: { url in
            print("Opening source: \(url)")
        }
        
        VideoAuthorAttribution(
            authorHandle: "@creator",
            authorUrl: "https://www.youtube.com/@creator",
            originalSourceUrl: nil,
            platform: "youtube"
        ) { url in
            print("Opening author: \(url)")
        } onSourceTap: { url in
            print("Opening source: \(url)")
        }
    }
    .padding()
} 