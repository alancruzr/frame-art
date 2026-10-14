import RealityKit
import SwiftUI

struct ArtworkARContainer: View {
    let piece: ArtworkPiece
    @Environment(\.dismiss) private var dismiss
    @State private var placement = ARPlacementState()
    @State private var snapshot: UIImage?

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

                    ARPlacementOverlay(
                        placement: placement,
                        widthCentimeters: piece.widthCentimeters,
                        heightCentimeters: piece.heightCentimeters
                    ) { snapshot = $0 }
                }
#endif
            }
            .sheet(isPresented: Binding(get: { snapshot != nil }, set: { if !$0 { snapshot = nil } })) {
                if let snapshot {
                    ARSnapshotSheet(
                        image: snapshot,
                        title: piece.title.isEmpty ? "la obra" : piece.title,
                        link: piece.publicSlug.isEmpty ? nil
                            : ClientViewer.shareURL(studio: ArtistProfile.shared.slug, artwork: piece.publicSlug)
                    )
                    .presentationDetents([.large])
                }
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
