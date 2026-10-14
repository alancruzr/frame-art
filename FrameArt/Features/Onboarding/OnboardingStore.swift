import Foundation
import Observation
import UIKit

enum OnboardingGoalID: String, CaseIterable, Equatable {
    case painting
    case several
    case clientPreview
    case fair
    case commission

    var title: String {
        switch self {
        case .painting: return "Una pintura (foto)"
        case .several: return "Varias obras del taller"
        case .clientPreview: return "Mostrársela al cliente"
        case .fair: return "Una feria o exposición"
        case .commission: return "Un encargo a medida"
        }
    }

    var systemImage: String {
        switch self {
        case .painting: return "photo.artframe"
        case .several: return "square.grid.2x2"
        case .clientPreview: return "person.2"
        case .fair: return "building.columns"
        case .commission: return "paintbrush.pointed"
        }
    }
}

enum OnboardingPainID: String, CaseIterable, Equatable {
    case size
    case wall
    case decide
    case visit
    case chat

    var title: String {
        switch self {
        case .size: return "No imagina el tamaño real"
        case .wall: return "No ve cómo queda en su pared"
        case .decide: return "El cliente no se decide"
        case .visit: return "Tengo que ir a mostrarla"
        case .chat: return "WhatsApp aplasta la foto"
        }
    }

    var icon: String {
        switch self {
        case .size: return "ruler"
        case .wall: return "rectangle.portrait"
        case .decide: return "person.crop.circle.badge.questionmark"
        case .visit: return "car"
        case .chat: return "message"
        }
    }

    var problem: String {
        switch self {
        case .size: return "En una foto, 60 cm se ven igual que 1.20 m."
        case .wall: return "Una foto no dice si queda bien sobre el sofá."
        case .decide: return "Le gusta, pero no cierra."
        case .visit: return "Tengo que llevar la obra o ir a su casa."
        case .chat: return "En el chat se ve chica, recortada y con otro color."
        }
    }

    var action: String {
        switch self {
        case .size: return "Frame Studio pone el ancho y el alto reales en AR."
        case .wall: return "El cliente cuelga la obra en su pared, a tamaño real."
        case .decide: return "Un enlace y la obra está en su espacio."
        case .visit: return "WhatsApp recibe un enlace, no un archivo."
        case .chat: return "Recortamos el lienzo y la mostramos como cuadro."
        }
    }

    var outcome: String {
        switch self {
        case .size: return "El cliente ve si cabe, antes de comprar."
        case .wall: return "Decide con la pared de casa, no con el chat."
        case .decide: return "Verla colgada suele bastar para decidir."
        case .visit: return "La visita queda para cuando ya hay trato."
        case .chat: return "Ven la obra, no la foto del piso del taller."
        }
    }

    /// Línea personalizada para el paywall, como `paywallHeadline` en Clarity.
    var paywallHeadline: String {
        switch self {
        case .size: return "Que cada cliente vea\nel tamaño real"
        case .wall: return "Tus obras, colgadas\nen su pared"
        case .decide: return "Ayuda a tus clientes\na decidir"
        case .visit: return "Muestra sin moverte\ndel taller"
        case .chat: return "Tu obra, no una foto\naplastada"
        }
    }
}

/// Pantallas del onboarding (7): bienvenida → objetivo y dolor → permisos → prueba →
/// resultado → prueba social → paywall. El nombre del estudio se pide al compartir por primera vez.
enum OnboardingStep: Int, CaseIterable {
    case welcome, needs, permissions, demo, demoResult, socialProof, paywall

    var analyticsName: String {
        switch self {
        case .welcome: return "welcome"
        case .needs: return "needs"
        case .permissions: return "permissions"
        case .demo: return "demo_try"
        case .demoResult: return "demo_result"
        case .socialProof: return "social_proof"
        case .paywall: return "paywall"
        }
    }
}

@MainActor
@Observable
final class OnboardingStore {
    static let shared = OnboardingStore()
    static let userDefaultsKey = "onboardingComplete.v2"
    static let selectedGoalKey = "onboardingSelectedGoal"
    static let selectedPainKey = "onboardingSelectedPain"
    static let resumeStepKey = "onboardingResumeStep.v5"

    var step: Int = 0 {
        didSet { persistResumeStep() }
    }
    var isComplete: Bool
    var navigationDirection: Int = 1
    var selectedGoal: OnboardingGoalID?
    var selectedPain: OnboardingPainID?

    // Prueba (pantallas 6–7)
    var demoImage: UIImage?
    var demoWidthCentimeters: Double = 80
    var demoUsedSample = true

    var resolvedPain: OnboardingPainID { selectedPain ?? .wall }

    static let lastStep = OnboardingStep.paywall.rawValue
    private var pendingAdvance: Task<Void, Never>?
    private var trackedSteps: Set<Int> = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isComplete = defaults.bool(forKey: Self.userDefaultsKey)
        selectedGoal = defaults.string(forKey: Self.selectedGoalKey)
            .flatMap(OnboardingGoalID.init(rawValue:))
        selectedPain = defaults.string(forKey: Self.selectedPainKey)
            .flatMap(OnboardingPainID.init(rawValue:))
        if !isComplete {
            let saved = defaults.integer(forKey: Self.resumeStepKey)
            // Como Clarity: se reanuda donde quedó, pero nunca dentro de la prueba (la imagen no persiste).
            step = min(saved, OnboardingStep.permissions.rawValue)
        }
        #if DEBUG
        // Capturas/QA: `-OnboardingDebugStep N` abre el onboarding en la pantalla N (0 = bienvenida).
        if let raw = UserDefaults.standard.string(forKey: "OnboardingDebugStep"), let forced = Int(raw),
           OnboardingStep(rawValue: forced) != nil {
            isComplete = false
            step = forced
        }
        #endif
    }

    var currentStep: OnboardingStep { OnboardingStep(rawValue: step) ?? .welcome }

    var progress: Double {
        Double(step) / Double(Self.lastStep)
    }

    /// Barra superior solo antes de la prueba, igual que Clarity (`currentScreen < 5`).
    var showsTopBar: Bool { step < OnboardingStep.demo.rawValue }

    /// Atrás solo en las pantallas de preguntas; tras pedir permisos ya no se vuelve.
    var canGoBack: Bool { step > 0 && step < OnboardingStep.permissions.rawValue }

    func trackCurrentStepIfNeeded() {
        guard trackedSteps.insert(step).inserted else { return }
        Analytics.log(.onboardingStep(index: step, name: currentStep.analyticsName))
    }

    func next() {
        pendingAdvance?.cancel()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationDirection = 1
        if step < Self.lastStep {
            step += 1
        }
    }

    func back() {
        pendingAdvance?.cancel()
        guard canGoBack else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationDirection = -1
        step -= 1
    }

    func showPaywall() {
        navigationDirection = 1
        step = OnboardingStep.paywall.rawValue
    }

    func selectGoal(_ goal: OnboardingGoalID) {
        UISelectionFeedbackGenerator().selectionChanged()
        selectedGoal = goal
        defaults.set(goal.rawValue, forKey: Self.selectedGoalKey)
        Analytics.log(.onboardingGoalSelected(goal.rawValue))
    }

    func selectPain(_ pain: OnboardingPainID) {
        UISelectionFeedbackGenerator().selectionChanged()
        selectedPain = pain
        defaults.set(pain.rawValue, forKey: Self.selectedPainKey)
        Analytics.log(.onboardingPainSelected(pain.rawValue))
    }

    func complete() {
        pendingAdvance?.cancel()
        if !isComplete {
            Analytics.log(.onboardingCompleted)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isComplete = true
        demoImage = nil
        defaults.set(true, forKey: Self.userDefaultsKey)
        defaults.removeObject(forKey: Self.resumeStepKey)
    }

    private func persistResumeStep() {
        guard !isComplete else { return }
        defaults.set(step, forKey: Self.resumeStepKey)
    }

    private func advanceAfterSelection() {
        pendingAdvance?.cancel()
        pendingAdvance = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            next()
        }
    }
}
