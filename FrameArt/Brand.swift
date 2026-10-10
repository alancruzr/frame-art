import SwiftUI
import UIKit

enum FrameStudioBrand {
    static let hunter = Color(red: 0.12, green: 0.24, blue: 0.17)
    static let gold = Color(red: 0.83, green: 0.69, blue: 0.45)
    static let sapphire = Color(red: 0.24, green: 0.35, blue: 0.50)
}

extension View {
    /// System prominent button. Hunter tint for contrast in light and dark.
    /// iOS 26+: Liquid Glass prominent. iOS 18–25: borderedProminent.
    @ViewBuilder
    func primaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(FrameStudioBrand.hunter)
        } else {
            self
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(FrameStudioBrand.hunter)
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
