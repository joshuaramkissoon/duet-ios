import SwiftUI

struct VideoAuthorAttribution: View {
    let authorHandle: String
    let authorUrl: String
    let platform: String
    var onTap: (URL) -> Void
    
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
            Button(action: {
                if let url = URL(string: authorUrl) {
                    onTap(url)
                }
            }) {
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
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        VideoAuthorAttribution(
            authorHandle: "@timwoo12",
            authorUrl: "https://www.tiktok.com/@timwoo12",
            platform: "tiktok"
        ) { url in
            print("Opening: \(url)")
        }
        
        VideoAuthorAttribution(
            authorHandle: "@johndoe",
            authorUrl: "https://www.instagram.com/johndoe",
            platform: "instagram"
        ) { url in
            print("Opening: \(url)")
        }
        
        VideoAuthorAttribution(
            authorHandle: "@creator",
            authorUrl: "https://www.youtube.com/@creator",
            platform: "youtube"
        ) { url in
            print("Opening: \(url)")
        }
    }
    .padding()
} 