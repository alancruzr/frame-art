import ARKit
import RealityKit
import SwiftUI

@Observable
final class ARPlacementState {
    var message: String?
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
                ZStack(alignment: .bottom) {
                    ArtworkARView(piece: piece, placement: placement)
                        .ignoresSafeArea()
                    if let message = placement.message {
                        Text(message)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.regularMaterial)
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
}

#if !targetEnvironment(simulator)
struct ArtworkARView: UIViewRepresentable {
    let piece: ArtworkPiece
    var placement: ARPlacementState

    func makeCoordinator() -> Coordinator {
        Coordinator(placement: placement)
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
        let placement: ARPlacementState

        init(placement: ARPlacementState) {
            self.placement = placement
        }

        func placeArtwork(_ piece: ArtworkPiece, in arView: ARView) async {
            do {
                let child: Entity
                switch piece.kind {
                case .paintingPhoto:
                    guard let image = ArtworkFileStore.loadImage(for: piece) else {
                        placement.message = "No se encontró la imagen de la obra."
                        return
                    }
                    child = try await PaintingEntityFactory.makePaintingEntity(
                        image: image,
                        widthCentimeters: piece.widthCentimeters
                    )
                case .scan3D:
                    guard let url = ArtworkFileStore.usdzURL(for: piece) else {
                        placement.message = "No se encontró el archivo 3D."
                        return
                    }
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
                placement.message = piece.kind == .paintingPhoto
                    ? "Apunta a una pared para colocar la obra. Puedes moverla y rotarla."
                    : "Apunta a una superficie para colocar el escaneo. Puedes moverlo y rotarlo."

                if let model = child as? ModelEntity {
                    _ = arView.installGestures([.rotation, .translation], for: model)
                }
            } catch {
                placement.message = error.localizedDescription
            }
        }
    }
}
#endif
