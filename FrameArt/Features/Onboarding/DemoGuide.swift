import Foundation

/// Pasos de la prueba guiada del onboarding.
enum DemoGuideStep: Int, CaseIterable, Equatable {
    case choosePainting
    case scanWall
    case tapToPlace
    case adjust
    case share
    case finished

    var analyticsName: String {
        switch self {
        case .choosePainting: return "choose_painting"
        case .scanWall: return "scan_wall"
        case .tapToPlace: return "tap_to_place"
        case .adjust: return "adjust"
        case .share: return "share"
        case .finished: return "finished"
        }
    }
}

enum DemoGuideEvent: Equatable {
    case paintingChosen
    case wallDetected
    case wallLost
    case placed
    case adjusted
    case shareTapped
    case skip
}

/// Máquina de estados pura (sin UI) de la prueba guiada. Avanza solo con el evento real que
/// corresponde a cada paso; `skip` pasa al siguiente.
struct DemoGuide: Equatable {
    enum Mode: String, Equatable {
        /// ARKit real en el dispositivo.
        case ar
        /// Pared simulada: simulador, sin ARKit o sin permiso de cámara.
        case simulated
    }

    private(set) var mode: Mode
    private(set) var step: DemoGuideStep = .choosePainting

    init(mode: Mode) {
        self.mode = mode
    }

    var isFinished: Bool { step == .finished }

    /// Pasa a la pared simulada (p. ej. si la cámara se niega a mitad). No retrocede.
    mutating func fallBackToSimulated() {
        guard mode == .ar else { return }
        mode = .simulated
        if step == .scanWall { step = .tapToPlace }
    }

    /// Aplica un evento. Devuelve true si cambió el paso.
    @discardableResult
    mutating func handle(_ event: DemoGuideEvent) -> Bool {
        let before = step
        switch (step, event) {
        case (.choosePainting, .paintingChosen):
            step = mode == .ar ? .scanWall : .tapToPlace
        case (.scanWall, .wallDetected):
            step = .tapToPlace
        case (.tapToPlace, .wallLost) where mode == .ar:
            step = .scanWall
        case (.scanWall, .placed), (.tapToPlace, .placed):
            step = .adjust
        case (.adjust, .adjusted):
            step = .share
        case (.share, .shareTapped):
            step = .finished
        case (_, .skip):
            step = Self.next(after: step, mode: mode)
        default:
            break
        }
        return step != before
    }

    static func next(after step: DemoGuideStep, mode: Mode) -> DemoGuideStep {
        switch step {
        case .choosePainting: return mode == .ar ? .scanWall : .tapToPlace
        case .scanWall: return .tapToPlace
        case .tapToPlace: return .adjust
        case .adjust: return .share
        case .share, .finished: return .finished
        }
    }
}
