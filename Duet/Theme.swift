//
//  Theme.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 17/05/2025.
//
import SwiftUI

extension Color {
    // Main app colors - defined directly with RGB values
    static let appBackground = Color(hex: "F8F5F2") // Soft cream background
    static let appPrimary = Color(hex: "E88D67")    // Warm coral/peach
    static let appSecondary = Color(hex: "6DC0D5")  // Soft blue
    static let appAccent = Color(hex: "7FB069")     // Soft green
    static let appText = Color(hex: "2E2E2E")       // Off-black for text
    
    // Semantic aliases that use existing colors
    static let appSurface = Color.white
    static let appError = Color.red
    static let appSuccess = Color.green
    static let appDivider = Color.gray.opacity(0.2)
    static let appPrimaryLightBackground = Color.appPrimary.opacity(0.1) // Light primary background for buttons
    
    // Pastel colors for UI elements
    static let lightLavender = Color(hex: "D9D7F1")  // Light lavender background
    static let darkPurple = Color(hex: "6A60A9")     // Darker purple for text/icons
    
    /// Deep midnight slate with blue undertones - recommended
    static let midnightSlate = Color(hex: "1E293B")
    
    /// Warmer midnight slate with slight purple tint
    static let midnightSlateWarm = Color(hex: "1F2937")
    
    /// Classic midnight slate - pure and clean
    static let midnightSlateClassic = Color(hex: "0F172A")
    
    /// Softer midnight slate with gray undertones
    static let midnightSlateSoft = Color(hex: "334155")
    
    /// Rich midnight slate with deeper saturation
    static let midnightSlateRich = Color(hex: "0C1220")
}

// For quick testing without creating assets, you can use these fallbacks:
extension Color {
    static var fallbackAppBackground: Color { Color(hex: "F8F5F2") }
    static var fallbackAppPrimary: Color { Color(hex: "E88D67") }
    static var fallbackAppSecondary: Color { Color(hex: "6DC0D5") }
    static var fallbackAppAccent: Color { Color(hex: "7FB069") }
    static var fallbackAppText: Color { Color(hex: "2E2E2E") }
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
    func body(content: Content) -> some View {
        content
            .withAppBackground()
            .accentColor(.appPrimary)
            .foregroundColor(.appText)
            .preferredColorScheme(.light) // Or use a state to toggle
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
