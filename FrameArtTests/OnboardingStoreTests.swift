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
            "welcome", "demo_try", "needs", "social_proof", "paywall"
        ])
    }

    @Test func demoComesBeforeQuestions() {
        #expect(OnboardingStep.demo.rawValue < OnboardingStep.needs.rawValue)
        let store = OnboardingStore(defaults: freshDefaults())
        #expect(!store.canGoBack)
        store.step = OnboardingStep.needs.rawValue
        #expect(store.showsTopBar)
        store.skipNeeds()
        #expect(store.currentStep == .socialProof)
        #expect(store.selectedPain == nil)
    }

    @Test func resumesWhereItLeft() {
        let defaults = freshDefaults()
        defaults.set(OnboardingStep.socialProof.rawValue, forKey: OnboardingStore.resumeStepKey)
        let store = OnboardingStore(defaults: defaults)
        #expect(store.step == OnboardingStep.socialProof.rawValue)
        defaults.set(99, forKey: OnboardingStore.resumeStepKey)
        #expect(OnboardingStore(defaults: defaults).step == OnboardingStore.lastStep)
    }

    @Test func selectingDoesNotAutoAdvance() {
        let store = OnboardingStore(defaults: freshDefaults())
        store.step = OnboardingStep.needs.rawValue
        store.selectGoal(.painting)
        store.selectPain(.size)
        #expect(store.step == OnboardingStep.needs.rawValue)
        #expect(OnboardingStep.allCases.count == 5)
    }
}
