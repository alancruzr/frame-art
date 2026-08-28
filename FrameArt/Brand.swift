import SwiftUI

enum FrameStudioBrand {
    static let hunter = Color(red: 0.12, green: 0.24, blue: 0.17)
    static let gold = Color(red: 0.83, green: 0.69, blue: 0.45)
    static let sapphire = Color(red: 0.24, green: 0.35, blue: 0.50)
}

extension View {
    /// HIG: system `borderedProminent` with gold as tint only — no custom chrome.
    func primaryButtonStyle() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(FrameStudioBrand.gold)
    }
}
