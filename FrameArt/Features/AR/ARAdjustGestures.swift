import ARKit
import RealityKit
import simd
import UIKit

#if !targetEnvironment(simulator)
/// Arrastrar (posición sobre la pared) tras colocar la obra. Sin pellizco: la obra
/// representa un cuadro real y su tamaño no debe cambiar (HIG Augmented reality).
/// Solo se instalan cuando `ARPlacementState.allowsAdjusting` es true (prueba del onboarding).
extension ArtworkARView.Coordinator {
    func installAdjustGestures(on arView: ARView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(pan)
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard hasPlacement, !isPinned, let arView, let worldAnchor, let normal = smoothedNormal else { return }
        switch gesture.state {
        case .began:
            placement.followsCamera = false
        case .changed:
            let point = gesture.location(in: arView)
            let hits = arView.raycast(from: point, allowing: .existingPlaneInfinite, alignment: .vertical)
                + arView.raycast(from: point, allowing: .estimatedPlane, alignment: .vertical)
            guard let hit = hits.first else { return }
            let position = WallPlacement.position(from: hit.worldTransform)
            smoothedPosition = position
            worldAnchor.transform = Transform(matrix: WallPlacement.hangingMatrix(position: position, normal: normal))
        case .ended:
            placement.adjustCount += 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        default:
            break
        }
    }
}
#endif
