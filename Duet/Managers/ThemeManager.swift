import SwiftUI
import Combine

// MARK: - Theme Mode Enum
enum ThemeMode: String, CaseIterable {
    case system = "system"
    case light = "light" 
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: ThemeMode {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? ThemeMode.system.rawValue
        self.currentTheme = ThemeMode(rawValue: savedTheme) ?? .system
    }
} 