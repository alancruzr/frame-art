import ARKit
import RealityKit
import SwiftUI

struct ArtworkARContainer: View {
    let piece: ArtworkPiece
    @Environment(\.dismiss) private var dismiss

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
                ArtworkARView(piece: piece)
                    .ignoresSafeArea()
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
}

#if !targetEnvironment(simulator)
struct ArtworkARView: UIViewRepresentable {
    let piece: ArtworkPiece

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false

        let config = ARWorldTrackingConfiguration()
        switch piece.kind {
        case .paintingPhoto:
            config.planeDetection = [.vertical]
        case .scan3D:
            config.planeDetection = [.horizontal, .vertical]
        }
        config.environmentTexturing = .automatic
        arView.session.run(config)

        let coaching = ARCoachingOverlayView()
        coaching.goal = piece.kind == .paintingPhoto ? .verticalPlane : .anyPlane
        coaching.session = arView.session
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: arView.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: arView.bottomAnchor),
        ])

        context.coordinator.task = Task { @MainActor in
            await context.coordinator.placeArtwork(piece, in: arView)
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.task?.cancel()
        uiView.session.pause()
    }

    @MainActor
    final class Coordinator {
        var task: Task<Void, Never>?

        func placeArtwork(_ piece: ArtworkPiece, in arView: ARView) async {
            do {
                let child: Entity
                switch piece.kind {
                case .paintingPhoto:
                    guard let image = ArtworkFileStore.loadImage(for: piece) else { return }
                    child = try await PaintingEntityFactory.makePaintingEntity(
                        image: image,
                        widthCentimeters: piece.widthCentimeters
                    )
                case .scan3D:
                    guard let url = ArtworkFileStore.usdzURL(for: piece) else { return }
                    child = try await PaintingEntityFactory.makeScanEntity(usdzURL: url)
                }

                let target: AnchoringComponent.Target
                switch piece.kind {
                case .paintingPhoto:
                    target = .plane(.vertical, classification: .wall, minimumBounds: [0.15, 0.15])
                case .scan3D:
                    target = .plane(.any, classification: .any, minimumBounds: [0.15, 0.15])
                }

                let anchor = AnchorEntity(target)
                anchor.addChild(child)
                arView.scene.addAnchor(anchor)

                if let model = child as? ModelEntity {
                    _ = arView.installGestures([.rotation, .translation], for: model)
                }
            } catch {
                print("Frame Art AR: \(error.localizedDescription)")
            }
        }
    }
}
#endif
