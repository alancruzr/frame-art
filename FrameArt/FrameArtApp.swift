import SwiftData
import SwiftUI

@main
struct FrameArtApp: App {
    @UIApplicationDelegateAdaptor(FrameStudioAppDelegate.self) private var appDelegate
    @State private var persistence = PersistenceController.make()
    @State private var onboarding = OnboardingStore.shared
    @State private var router = DeepLinkRouter.shared

    init() {
        FirebaseTelemetry.configureIfAvailable()
        SubscriptionManager.shared.configure()
        Task { await PendingUnpublish.retryAll() }
    }

    var body: some Scene {
        WindowGroup {
            switch persistence {
            case .ready(let container):
                content(container: container)
                    .modelContainer(container)
            case .failed(let message):
                StorageErrorView(
                    message: message,
                    onRetry: { persistence = PersistenceController.make() },
                    onReset: { persistence = PersistenceController.backupAndReset() }
                )
            }
        }
    }

    @ViewBuilder
    private func content(container: ModelContainer) -> some View {
        Group {
            if onboarding.isComplete || router.deferOnboarding {
                RootView()
            } else {
                OnboardingContainerView(store: onboarding)
            }
        }
        .onChange(of: router.pendingURL) { _, url in
            guard let url else { return }
            router.pendingURL = nil
            handleIncoming(url, container: container)
        }
        .onOpenURL { url in
            handleIncoming(url, container: container)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            handleIncoming(url, container: container)
        }
    }

    private func handleIncoming(_ url: URL, container: ModelContainer) {
        if ClientViewer.parseArtworkLink(url) != nil {
            router.deferOnboarding = true
        }
        Task { await router.open(url: url, context: container.mainContext) }
    }
}
