import Foundation
import Observation
import UIKit

enum OnboardingGoalID: String, CaseIterable, Equatable {
    case painting
    case scan
    case several
    case clientPreview
    case fair
    case commission

    var title: String {
        switch self {
        case .painting: return "Una pintura (foto)"
        case .scan: return "Un escaneo 3D"
        case .several: return "Varias obras del taller"
        case .clientPreview: return "Mostrársela al cliente"
        case .fair: return "Una feria o exposición"
        case .commission: return "Un encargo a medida"
        }
    }

    var systemImage: String {
        switch self {
        case .painting: return "photo.artframe"
        case .scan: return "cube"
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
}

@MainActor
@Observable
final class OnboardingStore {
    static let shared = OnboardingStore()
    static let userDefaultsKey = "onboardingComplete.v2"
    static let selectedGoalKey = "onboardingSelectedGoal"
    static let selectedPainKey = "onboardingSelectedPain"

    /// 0 welcome, 1 goal, 2 pain, 3 solution, 4 studio, 5 camera
    var step: Int = 0
    var isComplete: Bool
    var navigationDirection: Int = 1
    var selectedGoal: OnboardingGoalID?
    var selectedPain: OnboardingPainID?

    var resolvedPain: OnboardingPainID { selectedPain ?? .wall }

    private static let lastStep = 5
    private var pendingAdvance: Task<Void, Never>?

    private init() {
        isComplete = UserDefaults.standard.bool(forKey: Self.userDefaultsKey)
        selectedGoal = UserDefaults.standard.string(forKey: Self.selectedGoalKey)
            .flatMap(OnboardingGoalID.init(rawValue:))
        selectedPain = UserDefaults.standard.string(forKey: Self.selectedPainKey)
            .flatMap(OnboardingPainID.init(rawValue:))
    }

    var progress: Double {
        Double(step) / Double(Self.lastStep)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationDirection = -1
        if step > 0 {
            step -= 1
        }
    }

    func selectGoal(_ goal: OnboardingGoalID) {
        UISelectionFeedbackGenerator().selectionChanged()
        selectedGoal = goal
        UserDefaults.standard.set(goal.rawValue, forKey: Self.selectedGoalKey)
        advanceAfterSelection()
    }

    func selectPain(_ pain: OnboardingPainID) {
        UISelectionFeedbackGenerator().selectionChanged()
        selectedPain = pain
        UserDefaults.standard.set(pain.rawValue, forKey: Self.selectedPainKey)
        advanceAfterSelection()
    }

    func complete() {
        pendingAdvance?.cancel()
        if ArtistProfile.shared.slug.isEmpty {
            ArtistProfile.shared.save(displayName: ArtistProfile.shared.displayName, slug: "")
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isComplete = true
        UserDefaults.standard.set(true, forKey: Self.userDefaultsKey)
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
