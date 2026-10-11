import ARKit
import os
import RealityKit
import simd
import SwiftUI
import UIKit

#if !targetEnvironment(simulator)
struct ArtworkARView: UIViewRepresentable {
    let piece: ArtworkPiece
    var placement: ARPlacementState

    func makeCoordinator() -> Coordinator {
        Coordinator(piece: piece, placement: placement)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.renderOptions.insert(.disableMotionBlur)
        arView.debugOptions = [.showFeaturePoints]
        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = piece.kind == .paintingPhoto ? [.vertical] : [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        context.coordinator.attachCoaching(to: arView)
        context.coordinator.task = Task {
            await context.coordinator.bootstrap()
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.task?.cancel()
        uiView.session.delegate = nil
        uiView.session.pause()
    }

}
#endif
