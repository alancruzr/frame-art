import Foundation

/// Pasos de la prueba guiada. Reflejan los controles reales de la app:
/// Colocar aquí → Fijar → mirarla (momento «ajá») → valor.
enum DemoGuideStep: Int, CaseIterable, Equatable {
    case choosePainting
    case scanWall
    case tapToPlace
    case pin
    case explore
    case value
    case finished

    var analyticsName: String {
        switch self {
        case .choosePainting: return "choose_painting"
        case .scanWall: return "scan_wall"
        case .tapToPlace: return "tap_to_place"
        case .pin: return "pin"
        case .explore: return "explore"
        case .value: return "value"
        case .finished: return "finished"
        }
    }
}

enum DemoGuideEvent: Equatable {
    case paintingChosen
    case wallDetected
    case wallLost
    case placed
    case pinned
    case unpinned
    case moved
    /// La obra lleva `DemoGuide.ahaSeconds` fijada y a la vista.
    case ahaReached
    case continueTapped
    case skip
}

/// Máquina de estados pura (sin UI). Avanza solo con el evento real de cada paso;
/// `skip` pasa al siguiente.
struct DemoGuide: Equatable {
    enum Mode: String, Equatable {
        /// ARKit real en el dispositivo.
        case ar
        /// Pared de ejemplo: simulador, sin ARKit, sin permiso de cámara o sin pared en 20 s.
        case simulated
    }

    /// Segundos fijada a la vista para contar el momento «ajá».
    static let ahaSeconds: TimeInterval = 3
    /// Sin pared en este tiempo se ofrece la pared de ejemplo.
    static let wallTimeoutSeconds: TimeInterval = 20

    private(set) var mode: Mode
    private(set) var step: DemoGuideStep = .choosePainting

    init(mode: Mode) {
        self.mode = mode
    }

    var isFinished: Bool { step == .finished }

    /// Pasa a la pared de ejemplo. No retrocede.
    mutating func fallBackToSimulated() {
        guard mode == .ar else { return }
        mode = .simulated
        if step == .scanWall { step = .tapToPlace }
    }

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
            step = .pin
        case (.pin, .pinned):
            step = .explore
        case (.explore, .unpinned):
            step = .pin
        case (.pin, .moved), (.explore, .moved):
            step = mode == .ar ? .scanWall : .tapToPlace
        case (.explore, .ahaReached):
            step = .value
        case (.value, .continueTapped):
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
        case .tapToPlace: return .pin
        case .pin: return .explore
        case .explore: return .value
        case .value, .finished: return .finished
        }
    }
}
