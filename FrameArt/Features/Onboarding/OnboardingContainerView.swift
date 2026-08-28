import SwiftUI

struct OnboardingContainerView: View {
    @Bindable var store: OnboardingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: OnboardingStore = .shared) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            stepContent
                .id(store.step)
                .transition(reduceMotion ? .identity : .opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if store.step > 0 {
                            Button {
                                store.back()
                            } label: {
                                Image(systemName: "chevron.backward")
                            }
                            .accessibilityLabel("Atrás")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        ProgressView(value: Double(store.step + 1), total: 4)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 140)
                            .tint(FrameStudioBrand.gold)
                            .accessibilityLabel("Progreso")
                            .accessibilityValue("Paso \(store.step + 1) de 4")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Saltar") {
                            store.skip()
                        }
                    }
                }
        }
        .tint(FrameStudioBrand.hunter)
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
        default:
            PermissionsScreen(store: store)
        }
    }
}

#Preview("Onboarding") {
    OnboardingContainerView(store: OnboardingStore.shared)
}
