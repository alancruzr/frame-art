import ARKit
import os
import RealityKit
import simd
import SwiftUI
import UIKit

#if !targetEnvironment(simulator)
extension ArtworkARView {
    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        let piece: ArtworkPiece
        let placement: ARPlacementState
        weak var arView: ARView?
        var task: Task<Void, Never>?
        var ghost: ModelEntity?
        var worldAnchor: AnchorEntity?
        var coaching: ARCoachingOverlayView?
        var planeHints: [UUID: AnchorEntity] = [:]
        var isPinned = false
        var hasPlacement = false
        var verticalPlaneCount = 0
        var tickQueued = false
        var stableFrames = 0
        var smoothedPosition: SIMD3<Float>?
        var smoothedNormal: SIMD3<Float>?
        var lastUIPublish: TimeInterval = 0
        var lastTickLog: TimeInterval = 0
        let framesBeforeReady = 18

        init(piece: ArtworkPiece, placement: ARPlacementState) {
            self.piece = piece
            self.placement = placement
            super.init()
            placement.placeHandler = { [weak self] in self?.placeOnWall() }
            placement.moveHandler = { [weak self] in self?.moveToNewWall() }
            placement.pinHandler = { [weak self] in self?.pinToWall() }
        }

        func attachCoaching(to arView: ARView) {
            let overlay = ARCoachingOverlayView()
            overlay.goal = .verticalPlane
            overlay.session = arView.session
            overlay.activatesAutomatically = true
            overlay.translatesAutoresizingMaskIntoConstraints = false
            arView.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: arView.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
            ])
            coaching = overlay
        }

        func bootstrap() async {
            guard let arView else { return }
            do {
                let child: ModelEntity
                switch piece.kind {
                case .paintingPhoto:
                    guard let image = ArtworkFileStore.loadImage(for: piece) else {
                        arLog.error("AR image missing for \(self.piece.id.uuidString, privacy: .public)")
                        placement.phase = .failed
                        placement.message = "No se encontró la imagen de la obra."
                        return
                    }
                    let aspect = Double(image.size.height / max(image.size.width, 1))
                    child = try await PaintingEntityFactory.makePaintingEntity(
                        image: image,
                        widthCentimeters: piece.widthCentimeters,
                        heightCentimeters: piece.resolvedHeightCentimeters(aspect: aspect),
                        opacity: 0.82
                    )
                case .scan3D:
                    guard let url = ArtworkFileStore.usdzURL(for: piece) else {
                        placement.phase = .failed
                        placement.message = "No se encontró el archivo 3D."
                        return
                    }
                    let loaded = try await PaintingEntityFactory.makeScanEntity(usdzURL: url)
                    if let model = loaded as? ModelEntity {
                        child = model
                    } else if let model = loaded.children.compactMap({ $0 as? ModelEntity }).first {
                        child = model
                    } else {
                        let wrapper = ModelEntity()
                        wrapper.addChild(loaded)
                        child = wrapper
                    }
                }

                child.isEnabled = false
                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(child)
                arView.scene.addAnchor(anchor)
                ghost = child
                worldAnchor = anchor
                placement.phase = .searching
                placement.canPlace = false
                placement.message = searchCopy
            } catch {
                arLog.error("AR bootstrap failed: \(error.localizedDescription, privacy: .public)")
                placement.phase = .failed
                placement.message = error.localizedDescription
            }
        }

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            Task { @MainActor [weak self] in
                guard let self, !self.tickQueued else { return }
                self.tickQueued = true
                self.tick()
                self.tickQueued = false
            }
        }

        nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            let planes = anchors.compactMap { $0 as? ARPlaneAnchor }.filter { $0.alignment == .vertical }
            guard !planes.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.addPlaneHints(planes)
            }
        }

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            let planes = anchors.compactMap { $0 as? ARPlaneAnchor }.filter { $0.alignment == .vertical }
            guard !planes.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.updatePlaneHints(planes)
            }
        }

        nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            let ids = anchors.compactMap { $0 as? ARPlaneAnchor }.map(\.identifier)
            guard !ids.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.removePlaneHints(ids)
            }
        }
    }
}
#endif
