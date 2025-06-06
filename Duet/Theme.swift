//
//  Theme.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//
import SwiftUI

extension Color {
    // MARK: - Adaptive App Colors
    // These colors automatically adapt to light/dark mode with darker slate aesthetic
    static let appBackground = Color.adaptiveAppBackground // Use custom slate background
    static let appPrimary = Color.adaptivePrimary
    static let appSecondary = Color.adaptiveSecondary
    static let appAccent = Color.adaptiveAccent
    static let appText = Color(.label) // Use system label color
    
    // MARK: - Fallback Adaptive Colors
    // These provide good light/dark mode defaults with slate aesthetic
    static var adaptiveBackground: Color {
        Color(light: Color(hex: "F8F5F2"), dark: Color(hex: "1C1C1E"))
    }
    
    // Main app background - darker slate for better dark mode aesthetic
    static var adaptiveAppBackground: Color {
        Color(light: Color(hex: "F8F5F2"), dark: Color(hex: "0F1419")) // Dark slate blue-gray
    }
    
    // Card backgrounds - slightly lighter than app background for contrast
    static var adaptiveCardBackground: Color {
        Color(light: Color(.systemBackground), dark: Color(hex: "1A1F2A")) // Lighter slate for cards
    }
    
    static var adaptivePrimary: Color {
        Color(light: Color(hex: "E88D67"), dark: Color(hex: "FF9A7A"))
    }
    
    static var adaptiveSecondary: Color {
        Color(light: Color(hex: "6DC0D5"), dark: Color(hex: "7DD3F0"))
    }
    
    static var adaptiveAccent: Color {
        Color(light: Color(hex: "7FB069"), dark: Color(hex: "90C47A"))
    }
    
    static var adaptiveText: Color {
        Color(light: Color(hex: "2E2E2E"), dark: Color(hex: "E8E8E8"))
    }
    
    // MARK: - Semantic Colors
    static let appSurface = Color.adaptiveCardBackground // Use custom card background
    static let appSecondaryBackground = Color(.secondarySystemBackground)
    static let appError = Color(.systemRed)
    static let appSuccess = Color(.systemGreen)
    static let appDivider = Color(.separator)
    static let appPrimaryLightBackground = Color.appPrimary.opacity(0.1)
    static let appSecondaryLightBackground = Color.appSecondary.opacity(0.1)
    static let appAccentLightBackground = Color.appAccent.opacity(0.1)
    static let warmOrange = Color.adaptivePrimary
    static let softCream = Color(.systemGroupedBackground)
    
    // MARK: - Legacy Colors (for backward compatibility)
    static let lightLavender = Color(light: Color(hex: "D9D7F1"), dark: Color(hex: "2A2440"))
    static let darkPurple = Color(light: Color(hex: "6A60A9"), dark: Color(hex: "9B8ED4"))
    
    // Midnight slate variants (now adaptive)
    static let midnightSlate = Color(light: Color(hex: "1E293B"), dark: Color(.label))
    static let midnightSlateWarm = Color(light: Color(hex: "1F2937"), dark: Color(.secondaryLabel))
    static let midnightSlateClassic = Color(light: Color(hex: "0F172A"), dark: Color(.label))
    static let midnightSlateSoft = Color(light: Color(hex: "334155"), dark: Color(.secondaryLabel))
    static let midnightSlateRich = Color(light: Color(hex: "0C1220"), dark: Color(.label))
}

// MARK: - Light/Dark Color Helper
extension Color {
    /// Creates a color that adapts to light and dark appearance
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// For quick testing without creating assets, you can use these fallbacks:
extension Color {
    static var fallbackAppBackground: Color { Color(.systemGroupedBackground) }
    static var fallbackAppPrimary: Color { Color.adaptivePrimary }
    static var fallbackAppSecondary: Color { Color.adaptiveSecondary }
    static var fallbackAppAccent: Color { Color.adaptiveAccent }
    static var fallbackAppText: Color { Color(.label) }
}

// MARK: - Background View Modifier
struct AppBackgroundStyle: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Base layer - extends beyond safe area
            Color.appBackground
                .ignoresSafeArea()
            
            // Content layer
            content
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Applies the standard app background to the view
    func withAppBackground() -> some View {
        self.modifier(AppBackgroundStyle())
    }
}

// MARK: - Root View Modifier (Apply to your main ContentView)
struct AppThemeModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .withAppBackground()
            .accentColor(.appPrimary)
            .foregroundColor(.appText)
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
            .environmentObject(themeManager)
    }
}

// Convenience extension for the root view
extension View {
    /// Apply this to your ContentView to set the app theme
    func withAppTheme() -> some View {
        self.modifier(AppThemeModifier())
    }
}

// Helper for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

func getColorForText(_ text: String) -> Color {
    let colors: [Color] = [.appPrimary, .appSecondary, .appAccent, .blue, .purple, .teal, .pink]
    let total = text.unicodeScalars.map({ Int($0.value) }).reduce(0, +)
    return colors[total % colors.count]
}
