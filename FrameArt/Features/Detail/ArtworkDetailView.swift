import SwiftData
import SwiftUI
import UIKit

struct ArtworkDetailView: View {
    @Bindable var piece: ArtworkPiece
    @State private var showAR = false
    @State private var usdzURL: URL?
    @State private var glbURL: URL?
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                thumbnail
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                TextField("Título", text: $piece.title)
                if piece.kind == .scan3D {
                    LabeledContent("Tamaño") {
                        Text("Del escaneo")
                    }
                } else {
                    Stepper(value: $piece.widthCentimeters, in: 10...400, step: 1) {
                        LabeledContent("Ancho real") {
                            Text("\(Int(piece.widthCentimeters)) cm")
                        }
                    }
                    if let image = ArtworkFileStore.loadImage(for: piece), image.size.width > 0 {
                        let height = piece.widthCentimeters * (image.size.height / image.size.width)
                        LabeledContent("Alto estimado") {
                            Text("\(Int(height.rounded())) cm")
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Tipo") {
                    Text(piece.kind.title)
                }
            } header: {
                Text("Datos")
            } footer: {
                if piece.kind == .scan3D {
                    Text("El escaneo ya trae su tamaño.")
                } else {
                    Text("El cliente verá este tamaño real en su pared.")
                }
            }

            Section {
                Button {
                    showAR = true
                } label: {
                    Label("Ver en mi espacio", systemImage: "cube.transparent")
                        .frame(minHeight: 44, alignment: .leading)
                }
            } footer: {
                Text("Coloca la obra en una pared con ARKit. Hace falta un iPhone o iPad real.")
            }

            Section {
                if let usdzURL, let glbURL {
                    ShareLink(
                        items: [usdzURL, glbURL],
                        preview: SharePreview(piece.title, image: Image(systemName: "square.and.arrow.up"))
                    ) {
                        Label("Compartir con el cliente", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                } else if let usdzURL {
                    ShareLink(
                        item: usdzURL,
                        preview: SharePreview(piece.title, image: Image(systemName: "cube.transparent"))
                    ) {
                        Label("Compartir con el cliente", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }

                if piece.kind == .scan3D, glbURL == nil {
                    Text("Este escaneo es USDZ (iPhone). Aún no hay GLB para Android.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isExporting {
                    ProgressView("Preparando la obra para AR…")
                }
            } header: {
                Text("Cliente")
            } footer: {
                Text("iPhone abre el USDZ (Quick Look). Android abre el GLB (Scene Viewer). El cliente no instala Frame Studio.")
            }
        }
        .navigationTitle(piece.title.isEmpty ? "Obra" : piece.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showAR) {
            ArtworkARContainer(piece: piece)
        }
        .task(id: exportToken) {
            await prepareExports()
        }
        .alert("No se pudo exportar", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var exportToken: String {
        "\(piece.id.uuidString)-\(piece.widthCentimeters)-\(piece.title)"
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ArtworkFileStore.loadImage(for: piece) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .accessibilityLabel("Imagen de \(piece.title.isEmpty ? "la obra" : piece.title)")
        } else {
            ContentUnavailableView(
                piece.kind.title,
                systemImage: piece.kind.systemImage
            )
            .frame(minHeight: 160)
        }
    }

    @MainActor
    private func prepareExports() async {
        isExporting = true
        defer { isExporting = false }
        do {
            try ArtworkExporter.exportShareMeshes(for: piece)
            usdzURL = ArtworkFileStore.usdzURL(for: piece)
            glbURL = ArtworkFileStore.glbURL(for: piece)
        } catch {
            errorMessage = error.localizedDescription
            usdzURL = ArtworkFileStore.usdzURL(for: piece)
            glbURL = ArtworkFileStore.glbURL(for: piece)
        }
    }
}
