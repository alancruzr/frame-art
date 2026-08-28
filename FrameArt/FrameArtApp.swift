import SwiftData
import SwiftUI

@main
struct FrameArtApp: App {
    @State private var onboarding = OnboardingStore.shared

    var body: some Scene {
        WindowGroup {
            if onboarding.isComplete {
                RootView()
            } else {
                OnboardingContainerView(store: onboarding)
            }
        }
        .modelContainer(for: ArtworkPiece.self)
    }
}
