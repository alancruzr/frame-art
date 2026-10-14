import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct ArtworkDetailView: View {
    @Bindable var piece: ArtworkPiece
    /// Recién guardada la primera obra: se piden los avisos y se sugiere compartir.
    var isFirstArtwork = false
    @AppStorage("shareTipDismissed") private var shareTipDismissed = false
    @AppStorage("clientPreviewSeen") private var clientPreviewSeen = false
    @State private var showClientPreview = false
    @State private var publishAfterPreview = false
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
    @State private var showPaywall = false
    @State private var pendingPushAsk = false
    @State private var showPushAsk = false
    @State private var viewCount: Int?
    @State private var linkCopied = false
    @State private var showQR = false
    @State private var showStudioName = false

    private var publishedLink: URL? {
        let studio = ArtistProfile.shared.slug
        guard !piece.publicSlug.isEmpty, !studio.isEmpty else { return nil }
        return ClientViewer.shareURL(studio: studio, artwork: piece.publicSlug)
    }
    @Environment(\.modelContext) private var modelContext

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

            if piece.publicSlug.isEmpty, !shareTipDismissed {
                Section {
                    ShareTipCard(
                        onShare: {
                            Analytics.log(.shareTipTapped)
                            startShare()
                        },
                        onDismiss: {
                            Analytics.log(.shareTipDismissed)
                            withAnimation { shareTipDismissed = true }
                        }
                    )
                }
            }

            Section {
                Button {
                    Analytics.log(.arOpened(source: "artist_detail"))
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
                    startShare()
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

                if let link = publishedLink {
                    LabeledContent("Estado") { PublishedBadge(count: viewCount) }
                    Button {
                        UIPasteboard.general.url = link
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        Analytics.log(.linkCopied)
                        linkCopied = true
                    } label: {
                        Label(linkCopied ? "Enlace copiado" : "Copiar enlace",
                              systemImage: linkCopied ? "checkmark" : "doc.on.doc")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    Button {
                        Analytics.log(.qrShown)
                        showQR = true
                    } label: {
                        Label("Mostrar código QR", systemImage: "qrcode")
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("WhatsApp recibe un enlace. El cliente abre la obra en su pared, sin instalar Frame Studio.")
                }
            }
        }
        .navigationTitle(piece.title.isEmpty ? "Obra" : piece.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(source: .publishLimit) { showPaywall = false }
        }
        .sheet(isPresented: $showClientPreview, onDismiss: {
            if publishAfterPreview {
                publishAfterPreview = false
                Task { await publishAndShare() }
            }
        }) {
            ClientLinkPreview(
                image: previewImage ?? ArtworkFileStore.loadImage(for: piece) ?? UIImage(),
                title: piece.title.isEmpty ? "Mi obra" : piece.title,
                widthCentimeters: piece.widthCentimeters
            ) {
                clientPreviewSeen = true
                publishAfterPreview = true
                showClientPreview = false
            }
            .presentationDetents([.large])
        }
        .task {
            // Avisos: se piden tras guardar la primera obra (ya no en el onboarding).
            guard isFirstArtwork else { return }
            try? await Task.sleep(for: .milliseconds(700))
            if await PushNotifications.shared.shouldPrompt() { showPushAsk = true }
        }
        .sheet(isPresented: $showStudioName) {
            NavigationStack {
                StudioNameView {
                    Task { await publishAndShare() }
                }
            }
        }
        .sheet(isPresented: $showQR) {
            if let publishedLink {
                QRCodeSheet(url: publishedLink, title: piece.title.isEmpty ? "Obra" : piece.title)
                    .presentationDetents([.medium, .large])
            }
        }
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
        .task(id: piece.publicSlug) {
            guard !piece.publicSlug.isEmpty else { return }
            viewCount = await ViewCounter.count(studio: ArtistProfile.shared.slug, artwork: piece.publicSlug)
        }
        .alert("Te avisamos cuando tu cliente abra la obra", isPresented: $showPushAsk) {
            Button("Activar avisos") {
                PushNotifications.shared.markPrompted()
                Task { await PushNotifications.shared.requestAuthorization() }
            }
            Button("Ahora no", role: .cancel) {
                PushNotifications.shared.markPrompted()
            }
        } message: {
            Text("Recibirás un aviso cuando alguien abra el enlace de una obra (como mucho uno cada 30 minutos por obra). No vemos quién es.")
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            if pendingPushAsk {
                pendingPushAsk = false
                showPushAsk = true
            }
        }) {
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

    /// La primera vez se enseña qué recibe el cliente; luego se pide el nombre del estudio (si falta) y se publica.
    private func startShare() {
        if clientPreviewSeen {
            Task { await publishAndShare() }
        } else {
            showClientPreview = true
        }
    }

    @MainActor
    private func publishAndShare() async {
        guard ArtistProfile.shared.hasStudioName else {
            showStudioName = true
            return
        }
        let alreadyPublished = !piece.publicSlug.isEmpty
        let publishedCount = (try? modelContext.fetchCount(
            FetchDescriptor<ArtworkPiece>(predicate: #Predicate { !$0.publicSlug.isEmpty })
        )) ?? 0
        guard ProPlan.canPublish(
            isPro: SubscriptionManager.shared.isPro,
            publishedCount: publishedCount,
            alreadyPublished: alreadyPublished
        ) else {
            Analytics.log(.publishLimitReached(limit: ProPlan.freePublishedLimit))
            showPaywall = true
            return
        }
        isPublishing = true
        defer { isPublishing = false }
        do {
            let url = try await ArtworkPublisher.publish(piece)
            publishedURL = url
            Analytics.log(.artworkPublished(isFirst: !alreadyPublished))
            Analytics.log(.artworkShared)
            shareTipDismissed = true
            PushNotifications.shared.syncToken()
            if !alreadyPublished, await PushNotifications.shared.shouldPrompt() {
                pendingPushAsk = true
            }
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Sugerencia contextual para compartir (sustituye al paso «Compartir» del onboarding).
private struct ShareTipCard: View {
    var onShare: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("¿Un cliente interesado?", systemImage: "person.2.wave.2")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ocultar sugerencia")
            }
            Text("Envíale un enlace: verá esta obra en su pared, a tamaño real, sin instalar nada.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onShare) {
                Label("Enviar a un cliente", systemImage: "paperplane")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
        }
        .padding(.vertical, 4)
    }
}
