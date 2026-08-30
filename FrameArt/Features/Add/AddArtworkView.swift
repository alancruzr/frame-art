import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AddArtworkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var widthCentimeters: Double = 60
    @State private var heightCentimeters: Double = 80
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var kind: ArtworkKind = .paintingPhoto
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var errorMessage: String?
    @State private var originalImage: UIImage?
    @State private var isCroppingCanvas = false
    @State private var didCropCanvas = false
    @State private var cropStatusMessage = "Recortando el lienzo…"
    @State private var canvasCropTask: Task<Void, Never>?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Form {
            Section {
                if cameraAvailable {
                    Button {
                        openCamera()
                    } label: {
                        Label("Tomar foto", systemImage: "camera")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                } else {
                    Label("Cámara no disponible en este dispositivo", systemImage: "camera")
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44, alignment: .leading)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Elegir de Fotos", systemImage: "photo.on.rectangle")
                        .frame(minHeight: 44, alignment: .leading)
                }
                Button {
                    showFileImporter = true
                } label: {
                    Label("Importar desde Archivos", systemImage: "folder")
                        .frame(minHeight: 44, alignment: .leading)
                }
            } header: {
                Text("Origen")
            } footer: {
                Text("Foto de una pintura: cámara, Fotos o Archivos.")
            }

            if let selectedImage {
                Section("Vista previa") {
                    ZStack {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .opacity(isCroppingCanvas ? 0.55 : 1)
                            .accessibilityLabel("Vista previa de la pintura")
                        if isCroppingCanvas {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(FrameStudioBrand.gold)
                                Text(cropStatusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())

                    if didCropCanvas, !isCroppingCanvas {
                        Text("Lienzo recortado")
                            .foregroundStyle(.secondary)
                        Button("Usar foto completa") {
                            restoreOriginalPhoto()
                        }
                        .foregroundStyle(FrameStudioBrand.hunter)
                        .frame(minHeight: 44, alignment: .leading)
                    } else if originalImage != nil, !isCroppingCanvas {
                        Button("Recortar lienzo") {
                            startCanvasCrop()
                        }
                        .foregroundStyle(FrameStudioBrand.hunter)
                        .frame(minHeight: 44, alignment: .leading)
                    }

                    Text(ArtworkKind.paintingPhoto.title)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Título", text: $title)
                ArtworkSizeFields(
                    widthCentimeters: $widthCentimeters,
                    heightCentimeters: $heightCentimeters,
                    image: selectedImage
                )
            } header: {
                Text("Obra")
            } footer: {
                Text("Mide el marco. El alto sale de la foto; puedes corregir ancho y alto. Esos centímetros son los de la pared.")
            }
        }
        .navigationTitle("Nueva obra")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .onChange(of: pickerItem) { _, item in
            Task { await loadPickerItem(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: Binding(
                get: { selectedImage },
                set: { newImage in
                    if let newImage {
                        applyNewPhoto(newImage)
                    }
                }
            ))
            .ignoresSafeArea()
        }
        .onDisappear {
            canvasCropTask?.cancel()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: ArtworkUTTypes.importable
        ) { result in
            handleFileImport(result)
        }
        .alert("No se pudo añadir", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Aceptar") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canSave: Bool {
        selectedImage != nil
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
                applyNewPhoto(image)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let image = UIImage(contentsOfFile: url.path) {
                applyNewPhoto(image)
            } else {
                errorMessage = "Este archivo no es una imagen."
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func applyNewPhoto(_ image: UIImage) {
        originalImage = image
        selectedImage = image
        kind = .paintingPhoto
        didCropCanvas = false
        startCanvasCrop()
    }

    private func startCanvasCrop() {
        guard let originalImage else { return }
        canvasCropTask?.cancel()
        isCroppingCanvas = true
        cropStatusMessage = "Recortando el lienzo…"
        canvasCropTask = Task {
            let result = await PaintingCanvasCropper.cropCanvas(from: originalImage) { message in
                Task { @MainActor in
                    cropStatusMessage = message
                }
            }
            guard !Task.isCancelled else { return }
            selectedImage = result.image
            didCropCanvas = result.didCrop
            isCroppingCanvas = false
        }
    }

    private func restoreOriginalPhoto() {
        canvasCropTask?.cancel()
        isCroppingCanvas = false
        didCropCanvas = false
        selectedImage = originalImage
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let piece = ArtworkPiece(
            title: trimmed.isEmpty ? "Sin título" : trimmed,
            widthCentimeters: widthCentimeters,
            heightCentimeters: heightCentimeters,
            kind: kind
        )
        do {
            guard let selectedImage else { return }
            piece.kind = .paintingPhoto
            piece.imageFileName = try ArtworkFileStore.saveJPEG(selectedImage, for: piece.id)
            try ArtworkExporter.exportShareMeshes(for: piece)
            modelContext.insert(piece)
            try modelContext.save()
            dismiss()
        } catch {
            ArtworkFileStore.deleteFiles(for: piece)
            errorMessage = error.localizedDescription
        }
    }
}

struct ArtworkSizeFields: View {
    @Binding var widthCentimeters: Double
    @Binding var heightCentimeters: Double
    var image: UIImage?
    @State private var lockAspect = true
    @State private var syncing = false

    private var aspect: Double {
        guard let image, image.size.width > 1 else { return 1 }
        return Double(image.size.height / image.size.width)
    }

    var body: some View {
        Toggle("Mantener proporción de la foto", isOn: $lockAspect)
        Stepper(value: $widthCentimeters, in: 10...400, step: 1) {
            LabeledContent("Ancho") {
                Text("\(Int(widthCentimeters.rounded())) cm")
            }
        }
        Stepper(value: $heightCentimeters, in: 10...400, step: 1) {
            LabeledContent("Alto") {
                Text("\(Int(heightCentimeters.rounded())) cm")
            }
        }
        .onChange(of: widthCentimeters) { _, newValue in
            guard lockAspect, !syncing, aspect > 0 else { return }
            syncing = true
            heightCentimeters = min(400, max(10, (newValue * aspect).rounded()))
            syncing = false
        }
        .onChange(of: heightCentimeters) { _, newValue in
            guard lockAspect, !syncing, aspect > 0 else { return }
            syncing = true
            widthCentimeters = min(400, max(10, (newValue / aspect).rounded()))
            syncing = false
        }
        .onChange(of: image != nil) { _, hasImage in
            guard hasImage else { return }
            applyAspectFromImage()
        }
        .onChange(of: image?.size.width) { _, _ in
            applyAspectFromImage()
        }
        .onChange(of: image?.size.height) { _, _ in
            applyAspectFromImage()
        }
        .onAppear {
            if heightCentimeters < 1, aspect > 0 {
                applyAspectFromImage()
            } else if heightCentimeters < 1 {
                heightCentimeters = widthCentimeters
            }
        }
    }

    private func applyAspectFromImage() {
        guard lockAspect, aspect > 0 else { return }
        syncing = true
        heightCentimeters = min(400, max(10, (widthCentimeters * aspect).rounded()))
        syncing = false
    }
}

