import ARKit
import os
import SwiftUI

// Estado observable y textos de la colocación en pared.
let arLog = Logger(subsystem: "com.alancruzr.frameart", category: "AR")

let searchCopy = "Apunta a una pared y deja el teléfono quieto unos segundos."
let measuringCopy = "Sigue quieto. Midiendo la pared…"
let readyCopy = "Pared lista. Pulsa Colocar aquí."
let placedCopy = "Así se ve colgada. Fíjala, o pulsa Mover para otra pared."


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

    func place() { placeHandler?() }
    func move() { moveHandler?() }
    func pin() { pinHandler?() }
}
