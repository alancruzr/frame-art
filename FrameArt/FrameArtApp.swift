import SwiftData
import SwiftUI

@main
struct FrameArtApp: App {
    private let container: ModelContainer
    @State private var onboarding = OnboardingStore.shared
    @State private var router = DeepLinkRouter.shared

    init() {
        PurchasesBootstrap.start()
        do {
            container = try ModelContainer(for: ArtworkPiece.self, ReceivedPiece.self)
        } catch {
            fatalError("No se pudo abrir SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarding.isComplete || router.deferOnboarding {
                    RootView()
                } else {
                    OnboardingContainerView(store: onboarding)
                }
            }
            .onOpenURL { url in
                handleIncoming(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                handleIncoming(url)
            }
        }
        .modelContainer(container)
    }

    private func handleIncoming(_ url: URL) {
        if ClientViewer.parseArtworkLink(url) != nil {
            router.deferOnboarding = true
        }
        Task { await router.open(url: url, context: container.mainContext) }
    }
}
