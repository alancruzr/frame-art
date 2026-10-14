import SwiftUI
import UIKit

enum FrameStudioBrand {
    // Saturated pastel-family accents stay legible on light and dark surfaces.
    static let accent = adaptive(light: (0.25, 0.18, 0.39), dark: (0.82, 0.77, 0.98), highContrastLight: (0.20, 0.13, 0.33), highContrastDark: (0.91, 0.88, 1.00))
    static let buttonFill = adaptive(light: (0.25, 0.18, 0.39), dark: (0.29, 0.23, 0.39), highContrastLight: (0.20, 0.13, 0.33), highContrastDark: (0.24, 0.18, 0.34))
    static let blue = adaptive(light: (0.20, 0.34, 0.62), dark: (0.67, 0.77, 1.00), highContrastLight: (0.14, 0.27, 0.53), highContrastDark: (0.82, 0.88, 1.00))
    static let canvas = adaptive(light: (0.96, 0.95, 0.99), dark: (0.08, 0.07, 0.11), highContrastLight: (1.00, 1.00, 1.00), highContrastDark: (0.03, 0.03, 0.04))
    static let surface = adaptive(light: (1.00, 1.00, 1.00), dark: (0.14, 0.13, 0.18), highContrastLight: (1.00, 1.00, 1.00), highContrastDark: (0.08, 0.08, 0.10))
    static let softLavender = adaptive(light: (0.91, 0.88, 0.98), dark: (0.24, 0.21, 0.32), highContrastLight: (0.87, 0.83, 0.97), highContrastDark: (0.19, 0.16, 0.27))
    static let softBlue = adaptive(light: (0.86, 0.91, 0.99), dark: (0.18, 0.23, 0.34), highContrastLight: (0.81, 0.88, 0.99), highContrastDark: (0.14, 0.19, 0.30))

    private static func adaptive(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat),
        highContrastLight: (CGFloat, CGFloat, CGFloat),
        highContrastDark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.accessibilityContrast == .high
                ? (traits.userInterfaceStyle == .dark ? highContrastDark : highContrastLight)
                : (traits.userInterfaceStyle == .dark ? dark : light)
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

extension View {
    /// System prominent button with a high-contrast Frame Studio accent.
    /// iOS 26+: Liquid Glass prominent. iOS 18–25: borderedProminent.
    @ViewBuilder
    func primaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(FrameStudioBrand.accent)
        } else {
            self
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(FrameStudioBrand.accent)
        }
    }

    /// Secondary button. iOS 26+: Liquid Glass. iOS 18–25: bordered.
    @ViewBuilder
    func secondaryGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass).controlSize(.large)
        } else {
            self.buttonStyle(.bordered).controlSize(.large)
        }
    }
}


enum FrameStudioSettings {
    @MainActor
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
