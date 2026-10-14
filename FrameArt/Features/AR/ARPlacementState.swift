import ARKit
import os
import SwiftUI

// Estado observable y textos de la colocación en pared.
let arLog = Logger(subsystem: "app.framestudio.ios", category: "AR")

let searchCopy = "Apunta a una pared y deja el teléfono quieto unos segundos."
let measuringCopy = "Sigue quieto. Midiendo la pared…"
let readyCopy = "Pared lista. Pulsa Colocar aquí."
let placedCopy = "Así se ve colgada. Fíjala, o pulsa Mover para otra pared."
let pinnedCopy = "Fijada a tamaño real. Acércate y aléjate para verla."


@MainActor
@Observable
final class ARPlacementState {
    enum Phase {
        case searching
        case aiming
        case pinned
        case failed
    }

    var phase: Phase = .searching
    var message: String? = searchCopy
    var canPlace = false
    var placeHandler: (() -> Void)?
    var moveHandler: (() -> Void)?
    var pinHandler: (() -> Void)?
    var unpinHandler: (() -> Void)?
    var snapshotHandler: ((@escaping @MainActor (UIImage?) -> Void) -> Void)?

    /// Pellizcar/arrastrar tras colocar (solo la prueba del onboarding lo activa).
    var allowsAdjusting = false
    /// Sube cada vez que termina un ajuste manual.
    var adjustCount = 0
    /// Escala aplicada por pellizco (1 = tamaño real).
    var scale: Float = 1
    var pinchBase: Float = 1
    /// Tras colocar, la obra sigue el centro de la pantalla hasta que el usuario la ajusta a mano.
    var followsCamera = true

    nonisolated static func clampScale(_ value: Float) -> Float {
        min(max(value, 0.5), 2)
    }

    func place() { placeHandler?() }
    func move() { moveHandler?() }
    func pin() { pinHandler?() }
    func unpin() { unpinHandler?() }

    /// Captura la vista AR (RealityKit `ARView.snapshot`). nil si no hay sesión.
    func snapshot() async -> UIImage? {
        guard let snapshotHandler else { return nil }
        return await withCheckedContinuation { continuation in
            snapshotHandler { continuation.resume(returning: $0) }
        }
    }
}
