import AVFoundation
import PhotosUI
import SwiftUI

// MARK: - Pantalla 4: permiso de cámara (Clarity: OnboardingPermissionsChecklistScreen)

struct PermissionsChecklistScreen: View {
    var store: OnboardingStore
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "Cámara para fotografiar\ny colgar la obra")
                    OnboardingSubtitle(text: "La usas para fotografiar tus obras y para verlas en una pared real con AR, a tamaño real. Las fotos de la galería se eligen con el selector del sistema; no pedimos acceso a Fotos.")
                }

                Spacer().frame(height: 24)

                VStack(spacing: 10) {
                    PermissionRow(
                        icon: "camera.fill",
                        title: "Cámara",
                        detail: "Para fotografiar la obra y verla en AR",
                        granted: cameraStatus == .authorized,
                        blocked: cameraStatus == .denied || cameraStatus == .restricted
                    ) { Task { await handleCamera() } }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(title: "Continuar") { store.next() }
                }
                .padding(.top, 34)
            }
        }
        .task {
            cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    private func handleCamera() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            Analytics.log(.permissionResult(kind: "camera", granted: granted))
            cameraStatus = granted ? .authorized : .denied
        case .denied, .restricted:
            FrameStudioSettings.open()
        default:
            cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let blocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: granted ? "checkmark.circle.fill" : (blocked ? "gear" : icon))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FrameStudioBrand.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(blocked ? "\(title): abrir Ajustes" : title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(granted ? "Permitido" : detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !granted {
                    Text(blocked ? "Ajustes" : "Permitir")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(FrameStudioBrand.accent)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(granted ? FrameStudioBrand.softBlue : FrameStudioBrand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(granted ? FrameStudioBrand.blue.opacity(0.55) : Color(uiColor: .separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(granted)
        .accessibilityValue(granted ? "Permitido" : "No permitido")
    }
}

// MARK: - Pantalla 5: prueba guiada (Clarity: OnboardingDemoRecordingScreen)

/// Paso (a): elegir la obra. Los pasos (b)–(e) viven en `GuidedDemoView` (AR real o pared simulada).
struct DemoTryScreen: View {
    var store: OnboardingStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var loading = false
    @State private var showGuide = false
    @State private var showPicker = false
    @State private var startedAt = Date.now

    private var usingSample: Bool { store.demoUsedSample || store.demoImage == nil }

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "Mírala a tamaño real\nen tu pared")
                    OnboardingSubtitle(text: usingSample
                        ? "Empieza con esta obra de ejemplo. Te guiamos: son tres toques."
                        : "Tu obra, a su tamaño real. Te guiamos: son tres toques.")
                }

                Spacer().frame(height: 20)

                WallPreview(image: usingSample ? SampleArtworkInfo.image : store.demoImage,
                            widthCentimeters: store.demoWidthCentimeters)
                    .frame(height: 240)
                    .padding(.horizontal, 24)

                if usingSample {
                    Text(SampleArtworkInfo.credit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ancho real: \(Int(store.demoWidthCentimeters)) cm")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(FrameStudioBrand.accent)
                        Slider(value: Binding(
                            get: { store.demoWidthCentimeters },
                            set: { store.demoWidthCentimeters = $0.rounded() }
                        ), in: 20...200)
                        .accessibilityLabel("Ancho de la obra")
                        .accessibilityValue("\(Int(store.demoWidthCentimeters)) centímetros")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(title: "Pruébalo en tu pared") {
                        startedAt = .now
                        Analytics.log(.onboardingDemoImage(source: usingSample ? "sample" : "photos"))
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showGuide = true
                    }
                    .disabled(loading)
                    HStack(spacing: 20) {
                        Button {
                            showPicker = true
                        } label: {
                            Label(usingSample ? "Probar con mi obra" : "Otra foto", systemImage: "photo.on.rectangle")
                                .font(.subheadline.weight(.semibold))
                                .frame(minHeight: 44)
                        }
                        if !usingSample {
                            Button("Usar la de ejemplo") {
                                store.demoImage = nil
                                store.demoUsedSample = true
                                store.demoWidthCentimeters = SampleArtworkInfo.widthCentimeters
                            }
                            .font(.subheadline)
                            .frame(minHeight: 44)
                        }
                    }
                    .disabled(loading)
                }
                .padding(.top, 20)
            }
        }
        .onAppear {
            if usingSample { store.demoWidthCentimeters = SampleArtworkInfo.widthCentimeters }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            loading = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    store.demoImage = (image.preparingThumbnail(of: CGSize(width: 1600, height: 1600)) ?? image).normalizedUpright()
                    store.demoUsedSample = false
                    if store.demoWidthCentimeters == SampleArtworkInfo.widthCentimeters { store.demoWidthCentimeters = 80 }
                }
                loading = false
            }
        }
        .fullScreenCover(isPresented: $showGuide) {
            guideView
        }
    }

    @ViewBuilder
    private var guideView: some View {
        let image = (usingSample ? SampleArtworkInfo.image : store.demoImage) ?? UIImage()
        let aspect = Double(image.size.height / max(image.size.width, 1))
        let width = usingSample ? SampleArtworkInfo.widthCentimeters : store.demoWidthCentimeters
        let height = usingSample ? SampleArtworkInfo.heightCentimeters : (width * aspect).rounded()
        GuidedDemoView(
            image: image,
            widthCentimeters: width,
            heightCentimeters: height,
            title: usingSample ? SampleArtworkInfo.title : "Mi obra",
            isOwnArtwork: !usingSample,
            startedAt: startedAt
        ) { outcome in
            showGuide = false
            switch outcome {
            case .startGallery, .skipped:
                store.next()
            case .tryAnother:
                // Vuelve a esta pantalla con el selector abierto para elegir otra obra.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    showPicker = true
                }
            }
        }
    }
}

/// Pared simulada con sofá de referencia (≈ 200 cm) y la obra a escala.
struct WallPreview: View {
    let image: UIImage?
    let widthCentimeters: Double
    var showsLabel = true

    private let wallWidthCentimeters: Double = 320

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / wallWidthCentimeters
            let artWidth = widthCentimeters * scale
            let aspect = image.map { $0.size.height / max($0.size.width, 1) } ?? 0.75
            let artHeight = min(artWidth * aspect, geo.size.height * 0.58)
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [FrameStudioBrand.softLavender, FrameStudioBrand.softBlue],
                    startPoint: .top, endPoint: .bottom
                )
                Image(systemName: "sofa.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200 * scale)
                    .foregroundStyle(FrameStudioBrand.accent.opacity(0.35))
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)
                artwork
                    .frame(width: artWidth, height: artHeight)
                    .clipped()
                    .padding(5)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.36)
                if showsLabel {
                    Text("\(Int(widthCentimeters)) cm")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.36 + artHeight / 2 + 18)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vista previa: obra de \(Int(widthCentimeters)) centímetros sobre un sofá")
    }

    @ViewBuilder
    private var artwork: some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            SampleArtwork()
        }
    }
}

// MARK: - Pantalla 6: resultado (Clarity: OnboardingDemoReplayScreen)

struct DemoResultScreen: View {
    var store: OnboardingStore

    private var pain: OnboardingPainID { store.resolvedPain }

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    OnboardingTitle(text: "Así la verá tu cliente")
                    OnboardingSubtitle(text: "Con el enlace, la cuelga en su pared con la cámara, a \(Int(store.demoWidthCentimeters)) cm reales.")
                }

                Spacer().frame(height: 20)

                WallPreview(image: store.demoImage, widthCentimeters: store.demoWidthCentimeters)
                    .frame(height: 230)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 18)

                VStack(spacing: 14) {
                    resultRow(icon: pain.icon, label: "Lo que se perdía", text: pain.problem)
                    resultRow(icon: "sparkles", label: "Lo que acabas de hacer", text: pain.action)
                    resultRow(icon: "checkmark.circle.fill", label: "Lo que cambia", text: pain.outcome)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(title: "Continuar") { store.next() }
                }
                .padding(.top, 24)
            }
        }
    }

    private func resultRow(icon: String, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(FrameStudioBrand.accent)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FrameStudioBrand.accent)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pantalla 7: prueba social (Clarity: SocialProofScreen, modo "outcomes")

/// Como Clarity con pocas reseñas: muestra resultados verdaderos (lo que la persona acaba de
/// configurar) en lugar de un muro de reseñas inventadas.
struct SocialProofScreen: View {
    var store: OnboardingStore

    private var items: [(String, String, String)] {
        var rows: [(String, String, String)] = [
            ("person.crop.square", "Tu estudio", ArtistProfile.shared.hasStudioName ? ArtistProfile.shared.displayName : "Listo para tu primera obra"),
            ("ruler", "Obra a tamaño real", "\(Int(store.demoWidthCentimeters)) cm, como en su pared"),
            ("link", "Un enlace para WhatsApp", "El cliente no instala nada: abre y la cuelga en AR")
        ]
        return rows
    }

    var body: some View {
        OnboardingScreenFrame {
            VStack(spacing: 0) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle).imageScale(.large)
                    .foregroundStyle(FrameStudioBrand.accent)
                    .accessibilityHidden(true)

                Spacer().frame(height: 18)

                VStack(spacing: 8) {
                    OnboardingTitle(text: "Tu taller está listo\npara vender en su pared")
                    OnboardingSubtitle(text: "Artistas usan Frame Studio para que el cliente decida con la obra colgada, no con una foto.")
                }

                Spacer().frame(height: 24)

                VStack(spacing: 10) {
                    ForEach(items, id: \.1) { icon, title, detail in
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(FrameStudioBrand.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(title).font(.subheadline.weight(.semibold))
                                Text(detail).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(FrameStudioBrand.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(title: "Continuar") { store.next() }
                }
                .padding(.top, 28)
            }
        }
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
        }
    }
}
