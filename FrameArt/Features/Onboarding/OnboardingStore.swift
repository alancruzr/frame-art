import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class OnboardingStore {
    static let shared = OnboardingStore()
    static let userDefaultsKey = "onboardingComplete"

    /// Steps 0...3: Welcome, Goal, Pain, Permissions.
    var step: Int = 0
    var isComplete: Bool

    var canGoBack: Bool { step > 0 }
    var progress: Double { Double(step + 1) / Double(Self.lastStep + 1) }

    private static let lastStep = 3

    private init() {
        isComplete = UserDefaults.standard.bool(forKey: Self.userDefaultsKey)
    }

    func next() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if step < Self.lastStep {
            step += 1
        }
    }

    func back() {
        if step > 0 {
            step -= 1
        }
    }

    func skip() {
        complete()
    }

    func complete() {
        isComplete = true
        UserDefaults.standard.set(true, forKey: Self.userDefaultsKey)
    }
}
