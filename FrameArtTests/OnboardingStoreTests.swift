import Foundation
import Testing
@testable import FrameArt

@MainActor
struct OnboardingStoreTests {
    private func freshDefaults() -> UserDefaults {
        let name = "OnboardingStoreTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test func stepListHasNoReminders() {
        #expect(OnboardingStep.allCases.map(\.analyticsName) == [
            "welcome", "needs", "permissions",
            "demo_try", "demo_result", "social_proof", "paywall"
        ])
    }

    @Test func backOnlyOnQuestionScreens() {
        let store = OnboardingStore(defaults: freshDefaults())
        #expect(!store.canGoBack)
        store.step = OnboardingStep.needs.rawValue
        #expect(store.canGoBack)
        store.step = OnboardingStep.permissions.rawValue
        #expect(!store.canGoBack)
    }

    @Test func resumesButNeverInsideDemo() {
        let defaults = freshDefaults()
        defaults.set(OnboardingStep.socialProof.rawValue, forKey: OnboardingStore.resumeStepKey)
        let store = OnboardingStore(defaults: defaults)
        #expect(store.step == OnboardingStep.permissions.rawValue)
    }

    @Test func selectingDoesNotAutoAdvance() {
        let store = OnboardingStore(defaults: freshDefaults())
        store.step = OnboardingStep.needs.rawValue
        store.selectGoal(.painting)
        store.selectPain(.size)
        #expect(store.step == OnboardingStep.needs.rawValue)
        #expect(OnboardingStep.allCases.count == 7)
    }
}
