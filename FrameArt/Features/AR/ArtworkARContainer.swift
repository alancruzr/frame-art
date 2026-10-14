import RealityKit
import SwiftUI

struct ArtworkARContainer: View {
    let piece: ArtworkPiece
    @Environment(\.dismiss) private var dismiss
    @State private var placement = ARPlacementState()
    @State private var snapshot: UIImage?
    @State private var isCapturing = false

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
                        if placement.phase == .aiming || placement.phase == .pinned {
                            TrueSizeLabel(widthCentimeters: piece.widthCentimeters, heightCentimeters: piece.heightCentimeters)
                                .padding(.top, 8)
                        }
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
                shutterButton
            }
            .padding()
        case .pinned:
            HStack(spacing: 12) {
                Button {
                    placement.move()
                } label: {
                    Text("Mover a otra pared")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .secondaryGlassButtonStyle()
                shutterButton
            }
            .padding()
        case .failed:
            EmptyView()
        }
    }

    private var shutterButton: some View {
        Button {
            Task {
                isCapturing = true
                defer { isCapturing = false }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if let image = await placement.snapshot() {
                    Analytics.log(.arSnapshotTaken)
                    snapshot = image
                }
            }
        } label: {
            Image(systemName: "camera.fill")
                .frame(width: 44, height: 44)
        }
        .secondaryGlassButtonStyle()
        .disabled(isCapturing)
        .accessibilityLabel("Tomar foto de la obra en la pared")
    }
}
