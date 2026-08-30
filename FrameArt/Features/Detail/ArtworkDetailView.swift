import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct ArtworkDetailView: View {
    @Bindable var piece: ArtworkPiece
    @State private var showAR = false
    @State private var glbURL: URL?
    @State private var isExporting = false
    @State private var isPublishing = false
    @State private var errorMessage: String?
    @State private var publishedURL: URL?
    @State private var showShareSheet = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isReplacingPhoto = false
    @State private var replaceStatus = "Recortando el lienzo…"
    @State private var previewImage: UIImage?
    @State private var photoRevision = 0

    var body: some View {
        List {
            Section {
                thumbnail
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                if piece.kind == .paintingPhoto {
                    Menu {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Tomar foto", systemImage: "camera") {
                                openCamera()
                            }
                        }
                        Button("Elegir de Fotos", systemImage: "photo.on.rectangle") {
                            showPhotoLibrary = true
                        }
                    } label: {
                        Label("Cambiar foto", systemImage: "photo.on.rectangle.angled")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .disabled(isReplacingPhoto)
                    .accessibilityHint("Tomar foto o elegir de Fotos")
                    if isReplacingPhoto {
                        ProgressView(replaceStatus)
                    }
                }
            } footer: {
                if piece.kind == .paintingPhoto {
                    Text("La foto nueva reemplaza esta. El lienzo se recorta solo.")
                }
            }

            Section {
                TextField("Título", text: $piece.title)
                if piece.kind == .scan3D {
                    LabeledContent("Tamaño") {
                        Text("Del escaneo")
                    }
                } else {
                    ArtworkSizeFields(
                        widthCentimeters: $piece.widthCentimeters,
                        heightCentimeters: $piece.heightCentimeters,
                        image: previewImage ?? ArtworkFileStore.loadImage(for: piece)
                    )
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
                Button {
                    Task { await publishAndShare() }
                } label: {
                    if isPublishing {
                        ProgressView("Publicando la obra…")
                            .frame(minHeight: 44, alignment: .leading)
                    } else {
                        Label("Compartir con el cliente", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                .disabled(isPublishing || isExporting)

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
                Text("WhatsApp recibe un enlace. El cliente abre la obra en su pared, sin instalar Frame Studio.")
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
        .alert("No se pudo completar", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showShareSheet) {
            if let publishedURL {
                ArtworkShareSheet(
                    url: publishedURL,
                    title: piece.title.isEmpty ? "Obra" : piece.title,
                    image: previewImage ?? ArtworkFileStore.loadImage(for: piece)
                )
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            Task { await loadPickerItem(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: Binding(
                get: { previewImage },
                set: { newImage in
                    if let newImage {
                        Task { await replacePhoto(newImage) }
                    }
                }
            ))
            .ignoresSafeArea()
        }
        .onAppear {
            if previewImage == nil {
                previewImage = ArtworkFileStore.loadImage(for: piece)
            }
        }
    }

    private var exportToken: String {
        "\(piece.id.uuidString)-\(piece.widthCentimeters)-\(piece.heightCentimeters)-\(piece.title)-\(photoRevision)"
    }

    @ViewBuilder
    private var thumbnail: some View {
        let image = previewImage ?? ArtworkFileStore.loadImage(for: piece)
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Imagen de \(piece.title.isEmpty ? "la obra" : piece.title)")
        } else {
            ContentUnavailableView(
                piece.kind.title,
                systemImage: piece.kind.systemImage
            )
            .frame(minHeight: 160)
        }
    }

    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            FrameStudioSettings.open()
        default:
            showCamera = true
        }
    }

    private func loadPickerItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await replacePhoto(image)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        pickerItem = nil
    }

    @MainActor
    private func replacePhoto(_ image: UIImage) async {
        isReplacingPhoto = true
        replaceStatus = "Recortando el lienzo…"
        defer { isReplacingPhoto = false }
        let result = await PaintingCanvasCropper.cropCanvas(from: image) { message in
            Task { @MainActor in
                replaceStatus = message
            }
        }
        do {
            piece.kind = .paintingPhoto
            piece.imageFileName = try ArtworkFileStore.saveJPEG(result.image, for: piece.id)
            let aspect = Double(result.image.size.height / max(result.image.size.width, 1))
            if aspect > 0 {
                piece.heightCentimeters = min(400, max(10, (piece.widthCentimeters * aspect).rounded()))
            }
            previewImage = result.image
            photoRevision += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func prepareExports() async {
        isExporting = true
        defer { isExporting = false }
        do {
            try ArtworkExporter.exportShareMeshes(for: piece)
            glbURL = ArtworkFileStore.glbURL(for: piece)
        } catch {
            errorMessage = error.localizedDescription
            glbURL = ArtworkFileStore.glbURL(for: piece)
        }
    }

    @MainActor
    private func publishAndShare() async {
        isPublishing = true
        defer { isPublishing = false }
        do {
            let url = try await ArtworkPublisher.publish(piece)
            publishedURL = url
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
