import SwiftUI

struct OnboardingContainerView: View {
    @Bindable var store: OnboardingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: OnboardingStore = .shared) {
        self.store = store
    }

    var body: some View {
        ZStack {
            FrameStudioBrand.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                if store.showsTopBar {
                    topBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }

                stepContent
                    .id(store.step)
                    .transition(screenTransition)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tint(FrameStudioBrand.accent)
        .onAppear { store.trackCurrentStepIfNeeded() }
        .onChange(of: store.step) { _, _ in store.trackCurrentStepIfNeeded() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if store.canGoBack {
                Button {
                    store.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Atrás")
            } else {
                Spacer().frame(width: 44)
            }

            ProgressView(value: store.progress)
                .tint(FrameStudioBrand.accent)
                .accessibilityLabel("Progreso")
                .accessibilityValue("Paso \(store.step + 1) de \(OnboardingStore.lastStep + 1)")

            Spacer().frame(width: 44)
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.currentStep {
        case .welcome: WelcomeScreen(store: store)
        case .demo: DemoTryScreen(store: store)
        case .needs: NeedsScreen(store: store)
        case .socialProof: SocialProofScreen(store: store)
        case .paywall: OnboardingPaywallStep(store: store)
        }
    }

    private var screenTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let insertion: Edge = store.navigationDirection >= 0 ? .trailing : .leading
        let removal: Edge = store.navigationDirection >= 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: insertion)),
            removal: .opacity.combined(with: .move(edge: removal))
        )
    }
}

/// Último paso: paywall suave, como en Clarity. Comprar, restaurar o cerrar completa el onboarding.
struct OnboardingPaywallStep: View {
    var store: OnboardingStore

    var body: some View {
        PaywallView(source: .onboarding, pain: store.selectedPain) {
            store.complete()
        }
        .onAppear {
            if SubscriptionManager.shared.isPro { store.complete() }
        }
    }
}

#Preview("Onboarding") {
    OnboardingContainerView(store: OnboardingStore.shared)
}
