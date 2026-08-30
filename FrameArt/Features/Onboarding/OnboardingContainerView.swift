import SwiftUI

struct OnboardingContainerView: View {
    @Bindable var store: OnboardingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: OnboardingStore = .shared) {
        self.store = store
    }

    var body: some View {
        ZStack {
            FrameStudioBrand.hunter.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                stepContent
                    .id(store.step)
                    .transition(screenTransition)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .tint(FrameStudioBrand.gold)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if store.step > 0 {
                Button {
                    store.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Atrás")
            } else {
                Spacer().frame(width: 44)
            }

            ProgressView(value: store.progress)
                .tint(FrameStudioBrand.gold)
                .accessibilityLabel("Progreso")
                .accessibilityValue("Paso \(store.step + 1) de 6")

            Spacer().frame(width: 44)
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case 0:
            WelcomeScreen(store: store)
        case 1:
            GoalScreen(store: store)
        case 2:
            PainScreen(store: store)
        case 3:
            SolutionScreen(store: store)
        case 4:
            ProfileScreen(store: store)
        default:
            PermissionsScreen(store: store)
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

#Preview("Onboarding") {
    OnboardingContainerView(store: OnboardingStore.shared)
}
