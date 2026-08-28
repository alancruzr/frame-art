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
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var importedUSDZ: URL?
    @State private var kind: ArtworkKind = .paintingPhoto
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var errorMessage: String?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Form {
            Section {
                if cameraAvailable {
                    Button {
                        showCamera = true
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
                    Label("Elegir de la galería", systemImage: "photo.on.rectangle")
                        .frame(minHeight: 44, alignment: .leading)
                }
                Button {
                    showFileImporter = true
                } label: {
                    Label("Importar archivo", systemImage: "folder")
                        .frame(minHeight: 44, alignment: .leading)
                }
            } header: {
                Text("Origen")
            } footer: {
                Text("Foto de una pintura, o un escaneo USDZ / Reality desde Archivos.")
            }

            if let selectedImage {
                Section("Vista previa") {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowInsets(EdgeInsets())
                        .accessibilityLabel("Vista previa de la pintura")
                    Text(ArtworkKind.paintingPhoto.title)
                        .foregroundStyle(.secondary)
                }
            } else if let importedUSDZ {
                Section("Vista previa") {
                    Label("Escaneo 3D listo para guardar", systemImage: "cube.transparent")
                    Text(importedUSDZ.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Obra") {
                TextField("Título", text: $title)
                Stepper(value: $widthCentimeters, in: 10...400, step: 1) {
                    LabeledContent("Ancho") {
                        Text("\(Int(widthCentimeters)) cm")
                    }
                }
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
            CameraPicker(image: $selectedImage)
                .ignoresSafeArea()
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
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canSave: Bool {
        selectedImage != nil || importedUSDZ != nil
    }

    private func loadPickerItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
                importedUSDZ = nil
                kind = .paintingPhoto
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
            let ext = url.pathExtension.lowercased()
            if ["usdz", "reality"].contains(ext) {
                do {
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + "." + ext)
                    if FileManager.default.fileExists(atPath: tmp.path) {
                        try FileManager.default.removeItem(at: tmp)
                    }
                    try FileManager.default.copyItem(at: url, to: tmp)
                    importedUSDZ = tmp
                    selectedImage = nil
                    kind = .scan3D
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = url.deletingPathExtension().lastPathComponent
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else if let image = UIImage(contentsOfFile: url.path) {
                selectedImage = image
                importedUSDZ = nil
                kind = .paintingPhoto
            } else {
                errorMessage = "Este archivo no es una imagen ni un USDZ o Reality."
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let piece = ArtworkPiece(
            title: trimmed.isEmpty ? "Sin título" : trimmed,
            widthCentimeters: widthCentimeters,
            kind: kind
        )
        do {
            if let selectedImage {
                piece.kind = .paintingPhoto
                piece.imageFileName = try ArtworkFileStore.saveJPEG(selectedImage, for: piece.id)
                try ArtworkExporter.exportShareMeshes(for: piece)
            } else if let importedUSDZ {
                piece.kind = .scan3D
                let name = "model." + importedUSDZ.pathExtension.lowercased()
                piece.usdzFileName = try ArtworkFileStore.copyFile(
                    from: importedUSDZ,
                    for: piece.id,
                    fileName: name
                )
            } else {
                return
            }
            modelContext.insert(piece)
            try modelContext.save()
            dismiss()
        } catch {
            ArtworkFileStore.deleteFiles(for: piece)
            errorMessage = error.localizedDescription
        }
    }
}
