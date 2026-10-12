import RealityKit
import SwiftUI

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
                .secondaryGlassButtonStyle()
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
            .secondaryGlassButtonStyle()
            .padding()
        case .failed:
            EmptyView()
        }
    }
}
