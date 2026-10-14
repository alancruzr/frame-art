import ARKit
import os
import RealityKit
import simd
import SwiftUI
import UIKit

#if !targetEnvironment(simulator)
/// Indicadores de planos verticales detectados.
extension ArtworkARView.Coordinator {
    func addPlaneHints(_ planes: [ARPlaneAnchor]) {
        guard let arView else { return }
        for plane in planes {
            guard planeHints[plane.identifier] == nil else { continue }
            let hint = makePlaneHint(for: plane)
            hint.isEnabled = !hasPlacement
            arView.scene.addAnchor(hint)
            planeHints[plane.identifier] = hint
            verticalPlaneCount += 1
        }
    }

    func updatePlaneHints(_ planes: [ARPlaneAnchor]) {
        for plane in planes {
            if planeHints[plane.identifier] == nil {
                addPlaneHints([plane])
            } else if !hasPlacement {
                resizePlaneHint(for: plane)
            }
        }
    }

    func removePlaneHints(_ ids: [UUID]) {
        for id in ids {
            if let hint = planeHints.removeValue(forKey: id) {
                hint.removeFromParent()
                verticalPlaneCount = max(0, verticalPlaneCount - 1)
            }
        }
    }

    func makePlaneHint(for plane: ARPlaneAnchor) -> AnchorEntity {
        let anchor = AnchorEntity(.anchor(identifier: plane.identifier))
        let model = ModelEntity(mesh: planeMesh(for: plane), materials: [hintMaterial()])
        model.name = "WallHint"
        anchor.addChild(model)
        return anchor
    }

    func resizePlaneHint(for plane: ARPlaneAnchor) {
        guard let anchor = planeHints[plane.identifier],
              let model = anchor.findEntity(named: "WallHint") as? ModelEntity else { return }
        model.model?.mesh = planeMesh(for: plane)
    }

    func planeMesh(for plane: ARPlaneAnchor) -> MeshResource {
        MeshResource.generatePlane(
            width: plane.planeExtent.width,
            depth: plane.planeExtent.height
        )
    }

    func hintMaterial() -> UnlitMaterial {
        var material = UnlitMaterial(color: UIColor(red: 0.83, green: 0.69, blue: 0.45, alpha: 0.22))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.22))
        return material
    }

    func showScanIndicators() {
        arView?.debugOptions.insert(.showFeaturePoints)
        coaching?.setActive(true, animated: true)
        for hint in planeHints.values {
            hint.isEnabled = true
        }
    }

    func hideScanIndicators() {
        arView?.debugOptions.remove(.showFeaturePoints)
        coaching?.setActive(false, animated: true)
        for hint in planeHints.values {
            hint.isEnabled = false
        }
    }
}
#endif
