import ARKit
import os
import RealityKit
import simd
import SwiftUI
import UIKit

#if !targetEnvironment(simulator)
/// Puntería, suavizado y colocación/fijado de la obra en la pared.
extension ArtworkARView.Coordinator {
    func tick() {
        guard !isPinned, let arView, worldAnchor != nil, ghost != nil else { return }
        guard arView.bounds.width > 1, arView.bounds.height > 1 else { return }
        switch arView.session.currentFrame?.camera.trackingState {
        case .normal:
            break
        default:
            if !hasPlacement {
                stableFrames = 0
                placement.canPlace = false
                publishUI(phase: .searching, message: searchCopy)
            }
            return
        }

        let hits = wallHits(in: arView)
        logTickIfNeeded(hitCount: hits.count)
        apply(hits: hits, camera: arView.session.currentFrame?.camera)
    }

    func apply(hits: [ARRaycastResult], camera: ARCamera?) {
        guard !isPinned, let worldAnchor else { return }

        var sample: (SIMD3<Float>, SIMD3<Float>)?
        for hit in hits {
            if let normal = WallPlacement.wallNormal(hit: hit, camera: camera) {
                sample = (WallPlacement.position(from: hit.worldTransform), normal)
                break
            }
        }

        guard let (position, normal) = sample else {
            if !hasPlacement {
                stableFrames = 0
                if placement.canPlace {
                    placement.canPlace = false
                }
                publishUI(phase: .searching, message: searchCopy)
            }
            return
        }

        if hasPlacement, let locked = smoothedNormal, let sp = smoothedPosition {
            let facing = simd_dot(locked, normal) < 0 ? -normal : normal
            guard simd_dot(locked, facing) > 0.85 else { return }
            if simd_length(position - sp) > 0.025 {
                smoothedPosition = sp + (position - sp) * 0.08
                if let moved = smoothedPosition {
                    worldAnchor.transform = Transform(
                        matrix: WallPlacement.hangingMatrix(position: moved, normal: locked)
                    )
                }
            }
            return
        }

        if verticalPlaneCount < 1 {
            publishUI(phase: .searching, message: searchCopy)
            return
        }

        if let current = smoothedNormal, simd_dot(current, normal) < 0.85 {
            smoothedPosition = position
            smoothedNormal = normal
            stableFrames = 0
            placement.canPlace = false
            publishUI(phase: .searching, message: measuringCopy)
            return
        }

        if let sp = smoothedPosition, let sn = smoothedNormal {
            let n = simd_dot(sn, normal) < 0 ? -normal : normal
            smoothedPosition = sp + (position - sp) * 0.12
            smoothedNormal = simd_normalize(sn + (n - sn) * 0.08)
        } else {
            smoothedPosition = position
            smoothedNormal = normal
        }
        stableFrames += 1

        if stableFrames >= framesBeforeReady {
            if !placement.canPlace {
                placement.canPlace = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                arLog.info("AR wall ready planes=\(self.verticalPlaneCount)")
            }
            publishUI(phase: .searching, message: readyCopy)
        } else {
            placement.canPlace = false
            publishUI(phase: .searching, message: measuringCopy)
        }
    }

    func placeOnWall() {
        guard !isPinned, !hasPlacement else { return }
        guard placement.canPlace,
              let worldAnchor,
              let ghost,
              let showPosition = smoothedPosition,
              let showNormal = smoothedNormal else {
            placement.message = "Todavía no hay una pared estable. Deja el teléfono quieto."
            return
        }
        worldAnchor.transform = Transform(
            matrix: WallPlacement.hangingMatrix(position: showPosition, normal: showNormal)
        )
        ghost.isEnabled = true
        hasPlacement = true
        placement.canPlace = false
        hideScanIndicators()
        let width = Int(piece.widthCentimeters.rounded())
        placement.phase = .aiming
        placement.message = "Así se ve colgada (\(width) cm). Fíjala, o pulsa Mover para otra pared."
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        arLog.info("AR placed \(self.piece.id.uuidString, privacy: .public)")
    }

    func moveToNewWall() {
        isPinned = false
        hasPlacement = false
        placement.canPlace = false
        stableFrames = 0
        smoothedPosition = nil
        smoothedNormal = nil
        ghost?.isEnabled = false
        if let ghost {
            PaintingEntityFactory.setOpacity(ghost, 0.82)
        }
        showScanIndicators()
        placement.phase = .searching
        placement.message = searchCopy
        arLog.info("AR move to new wall")
    }

    func pinToWall() {
        guard !isPinned else { return }
        guard hasPlacement, let ghost else {
            placement.message = "Primero coloca la obra en la pared."
            return
        }
        isPinned = true
        hideScanIndicators()
        ghost.isEnabled = true
        PaintingEntityFactory.setOpacity(ghost, 1)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        placement.phase = .pinned
        placement.message = "Obra colgada. Pulsa Mover para otra pared."
        arLog.info("AR pinned \(self.piece.id.uuidString, privacy: .public)")
    }

    func wallHits(in arView: ARView) -> [ARRaycastResult] {
        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let alignment: ARRaycastQuery.TargetAlignment = piece.kind == .paintingPhoto ? .vertical : .any
        let geometry = arView.raycast(from: center, allowing: .existingPlaneGeometry, alignment: alignment)
        if !geometry.isEmpty { return geometry }
        let infinite = arView.raycast(from: center, allowing: .existingPlaneInfinite, alignment: alignment)
        if !infinite.isEmpty { return infinite }
        return arView.raycast(from: center, allowing: .estimatedPlane, alignment: alignment)
    }

    func logTickIfNeeded(hitCount: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTickLog > 1.5 else { return }
        lastTickLog = now
        arLog.info("AR tick hits=\(hitCount) planes=\(self.verticalPlaneCount) placed=\(self.hasPlacement) stable=\(self.stableFrames) canPlace=\(self.placement.canPlace)")
    }

    func publishUI(phase: ARPlacementState.Phase, message: String) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastUIPublish > 0.25 || placement.phase != phase || placement.message != message else { return }
        lastUIPublish = now
        guard !isPinned else { return }
        placement.phase = phase
        placement.message = message
    }
}
#endif
