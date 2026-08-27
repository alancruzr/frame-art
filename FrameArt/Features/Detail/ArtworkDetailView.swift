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

            Section("Datos") {
                TextField("Título", text: $piece.title)
                Stepper(value: $piece.widthCentimeters, in: 10...400, step: 1) {
                    LabeledContent("Ancho") {
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
                LabeledContent("Tipo") {
                    Text(piece.kind.title)
                }
            }

            Section {
                Button {
                    showAR = true
                } label: {
                    Label("Ver en mi espacio", systemImage: "cube.transparent")
                }

                if let usdzURL {
                    ShareLink(
                        item: usdzURL,
                        preview: SharePreview(piece.title, image: Image(systemName: "cube.transparent"))
                    ) {
                        Label("Compartir USDZ (iPhone)", systemImage: "square.and.arrow.up")
                    }
                }

                if let glbURL {
                    ShareLink(
                        item: glbURL,
                        preview: SharePreview(piece.title, image: Image(systemName: "square.stack.3d.up"))
                    ) {
                        Label("Compartir GLB (Android)", systemImage: "square.and.arrow.up")
                    }
                } else if piece.kind == .scan3D {
                    Text("Este escaneo 3D es USDZ (iPhone). El visor público con GLB es para pinturas exportadas desde una foto.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isExporting {
                    ProgressView("Preparando archivos…")
                }
            } footer: {
                Text("Un solo enlace público (web/index.html en GitHub Pages) abre Quick Look en iPhone y Scene Viewer / model-viewer en Android. Los archivos sueltos sirven para Mensajes, WhatsApp y Archivos.")
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
