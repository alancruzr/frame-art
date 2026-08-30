import ARKit
import os
import RealityKit
import simd
import SwiftUI
import UIKit

private let arLog = Logger(subsystem: "com.alancruzr.frameart", category: "AR")

private let searchCopy = "Apunta a una pared y deja el teléfono quieto unos segundos."
private let measuringCopy = "Sigue quieto. Midiendo la pared…"
private let readyCopy = "Pared lista. Pulsa Colocar aquí."
private let placedCopy = "Así se ve colgada. Fíjala, o pulsa Mover para otra pared."

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
    fileprivate var placeHandler: (() -> Void)?
    fileprivate var moveHandler: (() -> Void)?
    fileprivate var pinHandler: (() -> Void)?

    func place() { placeHandler?() }
    func move() { moveHandler?() }
    func pin() { pinHandler?() }
}

private enum WallPlacement {
    static func hangingMatrix(position: SIMD3<Float>, normal: SIMD3<Float>) -> simd_float4x4 {
        let n = simd_normalize(normal)
        let worldUp = SIMD3<Float>(0, 1, 0)
        var right = simd_cross(worldUp, n)
        if simd_length(right) < 0.05 {
            right = simd_cross(SIMD3<Float>(1, 0, 0), n)
        }
        right = simd_normalize(right)
        let up = simd_normalize(simd_cross(n, right))
        let offset = position + n * 0.02
        return simd_float4x4(columns: (
            SIMD4(right.x, right.y, right.z, 0),
            SIMD4(up.x, up.y, up.z, 0),
            SIMD4(n.x, n.y, n.z, 0),
            SIMD4(offset.x, offset.y, offset.z, 1)
        ))
    }

    static func position(from transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    static func wallNormal(hit: ARRaycastResult, camera: ARCamera?) -> SIMD3<Float>? {
        var normal: SIMD3<Float>
        if let plane = hit.anchor as? ARPlaneAnchor, plane.alignment == .vertical {
            normal = simd_normalize(SIMD3(
                plane.transform.columns.1.x,
                plane.transform.columns.1.y,
                plane.transform.columns.1.z
            ))
        } else {
            let yAxis = simd_normalize(SIMD3(
                hit.worldTransform.columns.1.x,
                hit.worldTransform.columns.1.y,
                hit.worldTransform.columns.1.z
            ))
            let zAxis = simd_normalize(SIMD3(
                hit.worldTransform.columns.2.x,
                hit.worldTransform.columns.2.y,
                hit.worldTransform.columns.2.z
            ))
            normal = abs(yAxis.y) <= abs(zAxis.y) ? yAxis : zAxis
        }

        guard abs(normal.y) < 0.55 else { return nil }

        let position = position(from: hit.worldTransform)
        if let camera {
            let cam = SIMD3<Float>(
                camera.transform.columns.3.x,
                camera.transform.columns.3.y,
                camera.transform.columns.3.z
            )
            let toCamera = simd_normalize(cam - position)
            if simd_dot(normal, toCamera) < 0 {
                normal = -normal
            }
        }
        return normal
    }
}

struct ArtworkARContainer: View {
    let piece: ArtworkPiece
    @Environment(\.dismiss) private var dismiss
    @State private var placement = ARPlacementState()

    var body: some View {
        NavigationStack {
            Group {
#if targetEnvironment(simulator)
                ContentUnavailableView(
                    "AR no disponible",
                    systemImage: "cube",
                    description: Text("La vista previa en el espacio requiere un iPhone o iPad real con ARKit.")
                )
#else
                ZStack {
                    ArtworkARView(piece: piece, placement: placement)
                        .ignoresSafeArea()

                    VStack(spacing: 8) {
                        Spacer()
                        if let message = placement.message {
                            Text(message)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(.regularMaterial)
                        }
                        controls
                    }
                }
#endif
            }
            .navigationTitle("Mi espacio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch placement.phase {
        case .searching:
            Button {
                placement.place()
            } label: {
                Text("Colocar aquí")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
            .disabled(!placement.canPlace)
            .padding()
        case .aiming:
            HStack(spacing: 12) {
                Button {
                    placement.move()
                } label: {
                    Text("Mover")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                Button {
                    placement.pin()
                } label: {
                    Text("Fijar")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .primaryButtonStyle()
            }
            .padding()
        case .pinned:
            Button {
                placement.move()
            } label: {
                Text("Mover a otra pared")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding()
        case .failed:
            EmptyView()
        }
    }
}

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
        private var tickQueued = false
        private var stableFrames = 0
        private var smoothedPosition: SIMD3<Float>?
        private var smoothedNormal: SIMD3<Float>?
        private var lastUIPublish: TimeInterval = 0
        private var lastTickLog: TimeInterval = 0
        private let framesBeforeReady = 18

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

        private func makePlaneHint(for plane: ARPlaneAnchor) -> AnchorEntity {
            let anchor = AnchorEntity(.anchor(identifier: plane.identifier))
            let model = ModelEntity(mesh: planeMesh(for: plane), materials: [hintMaterial()])
            model.name = "WallHint"
            anchor.addChild(model)
            return anchor
        }

        private func resizePlaneHint(for plane: ARPlaneAnchor) {
            guard let anchor = planeHints[plane.identifier],
                  let model = anchor.findEntity(named: "WallHint") as? ModelEntity else { return }
            model.model?.mesh = planeMesh(for: plane)
        }

        private func planeMesh(for plane: ARPlaneAnchor) -> MeshResource {
            MeshResource.generatePlane(
                width: plane.planeExtent.width,
                depth: plane.planeExtent.height
            )
        }

        private func hintMaterial() -> UnlitMaterial {
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

        private func wallHits(in arView: ARView) -> [ARRaycastResult] {
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            let alignment: ARRaycastQuery.TargetAlignment = piece.kind == .paintingPhoto ? .vertical : .any
            let geometry = arView.raycast(from: center, allowing: .existingPlaneGeometry, alignment: alignment)
            if !geometry.isEmpty { return geometry }
            let infinite = arView.raycast(from: center, allowing: .existingPlaneInfinite, alignment: alignment)
            if !infinite.isEmpty { return infinite }
            return arView.raycast(from: center, allowing: .estimatedPlane, alignment: alignment)
        }

        private func logTickIfNeeded(hitCount: Int) {
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastTickLog > 1.5 else { return }
            lastTickLog = now
            arLog.info("AR tick hits=\(hitCount) planes=\(self.verticalPlaneCount) placed=\(self.hasPlacement) stable=\(self.stableFrames) canPlace=\(self.placement.canPlace)")
        }

        private func publishUI(phase: ARPlacementState.Phase, message: String) {
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastUIPublish > 0.25 || placement.phase != phase || placement.message != message else { return }
            lastUIPublish = now
            guard !isPinned else { return }
            placement.phase = phase
            placement.message = message
        }
    }
}
#endif
