import ARKit
import AVFoundation
import SwiftUI
import UIKit

/// Cómo terminó la prueba guiada.
enum DemoOutcome: Equatable {
    /// «Empezar mi galería».
    case startGallery
    /// «Probar con otra obra»: vuelve a elegir obra.
    case tryAnother
    /// «Saltar prueba».
    case skipped
}

/// Prueba guiada: usa la misma vista AR y los mismos controles que la app (`ARPlacementOverlay`,
/// `FijarButton`). Sin ARKit, sin cámara o sin pared en 20 s, una pared de ejemplo maneja el mismo
/// `ARPlacementState`, así que los botones, estados, hápticos y la etiqueta de tamaño son idénticos.
/// La mano señala el control real; cada paso avanza con el evento real.
struct GuidedDemoView: View {
    let image: UIImage
    let widthCentimeters: Double
    let heightCentimeters: Double
    let title: String
    let isOwnArtwork: Bool
    /// Momento en que el usuario tocó «Pruébalo en tu pared» (para medir el tiempo hasta el «ajá»).
    let startedAt: Date
    var onFinish: (DemoOutcome) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var guide: DemoGuide
    @State private var placement = ARPlacementState()
    @State private var piece: ArtworkPiece?
    @State private var ahaTask: Task<Void, Never>?
    @State private var wallTimeoutTask: Task<Void, Never>?
    @State private var simReadyTask: Task<Void, Never>?
    @State private var offerSampleWall = false
    @State private var snapshot: UIImage?

    init(image: UIImage, widthCentimeters: Double, heightCentimeters: Double, title: String,
         isOwnArtwork: Bool, startedAt: Date = .now, onFinish: @escaping (DemoOutcome) -> Void) {
        self.image = image
        self.widthCentimeters = widthCentimeters
        self.heightCentimeters = heightCentimeters
        self.title = title
        self.isOwnArtwork = isOwnArtwork
        self.startedAt = startedAt
        self.onFinish = onFinish
        var guide = DemoGuide(mode: Self.preferredMode())
        guide.handle(.paintingChosen)
        _guide = State(initialValue: guide)
    }

    static func preferredMode() -> DemoGuide.Mode {
        #if targetEnvironment(simulator)
        return .simulated
        #else
        guard ARWorldTrackingConfiguration.isSupported else { return .simulated }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined: return .ar
        default: return .simulated
        }
        #endif
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            stage
            if guide.step == .value {
                valueCard
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            } else {
                ARPlacementOverlay(
                    placement: placement,
                    widthCentimeters: widthCentimeters,
                    heightCentimeters: heightCentimeters,
                    showsShutter: guide.mode == .ar,
                    onSnapshot: { snapshot = $0 }
                ) {
                    guidanceCard
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
            topBar
        }
        .overlayPreferenceValue(PlacementControlAnchorKey.self) { anchors in
            handOverlay(anchors)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: guide.step)
        .preferredColorScheme(.dark)
        .task { await prepare() }
        .onDisappear { cleanup() }
        .onChange(of: placement.canPlace) { _, ready in
            if ready {
                send(.wallDetected)
            } else if placement.phase == .searching {
                send(.wallLost)
            }
        }
        .onChange(of: placement.phase) { old, phase in
            switch phase {
            case .aiming:
                send(old == .pinned ? .unpinned : .placed)
                wallTimeoutTask?.cancel()
                offerSampleWall = false
            case .pinned:
                send(.pinned)
                startAhaTimer()
            case .searching:
                if old != .searching { send(.moved) }
            case .failed:
                fallBack(reason: "ar_failed")
            }
            if phase != .pinned { ahaTask?.cancel() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { ahaTask?.cancel() }
            else if placement.phase == .pinned, guide.step == .explore { startAhaTimer() }
        }
        .sheet(isPresented: Binding(get: { snapshot != nil }, set: { if !$0 { snapshot = nil } })) {
            if let snapshot {
                ARSnapshotSheet(image: snapshot, title: title, link: nil)
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: Escena

    @ViewBuilder
    private var stage: some View {
        if guide.mode == .ar {
            #if !targetEnvironment(simulator)
            if let piece {
                ArtworkARView(piece: piece, placement: placement)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }
            #endif
        } else {
            SampleWallScene(
                image: image,
                widthCentimeters: widthCentimeters,
                heightCentimeters: heightCentimeters,
                phase: placement.phase
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        VStack {
            HStack {
                Text(guide.mode == .ar ? "Prueba en tu pared" : "Pared de ejemplo")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if guide.step != .value {
                    Button("Saltar prueba") {
                        Analytics.log(.demoGuideSkipped(step: guide.step.analyticsName))
                        finish(.skipped)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            .background(.black.opacity(0.25))
            Spacer()
        }
        // Debajo de la barra va la etiqueta de tamaño real de la capa compartida.
        .padding(.top, 0)
    }

    // MARK: Guía

    private var guidanceCard: some View {
        VStack(spacing: 10) {
            StepDots(current: guide.step, mode: guide.mode)
            Text(instruction)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if offerSampleWall {
                Button("Usar una pared de ejemplo") { fallBack(reason: "no_wall_timeout") }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
    }

    private var instruction: String {
        switch (guide.step, guide.mode) {
        case (.scanWall, _):
            return offerSampleWall
                ? "No encontramos una pared. Prueba con más luz o usa una de ejemplo."
                : "Apunta a una pared despejada y mueve el teléfono despacio."
        case (.tapToPlace, .ar): return "Pared lista. Toca «Colocar aquí»."
        case (.tapToPlace, .simulated): return "Toca «Colocar aquí» para colgarla en la pared."
        case (.pin, _): return "¿Te gusta ahí? Toca «Fijar»."
        case (.explore, .ar): return "Acércate y aléjate: así de grande es de verdad."
        case (.explore, .simulated): return "Fijada. Compárala con el sofá: así de grande es de verdad."
        default: return ""
        }
    }

    @ViewBuilder
    private func handOverlay(_ anchors: [PlacementControlID: Anchor<CGRect>]) -> some View {
        GeometryReader { geo in
            switch guide.step {
            case .scanWall where guide.mode == .ar:
                HandGestureHint(gesture: .scan)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            case .tapToPlace:
                if let a = anchors[.place], placement.canPlace {
                    pointer(at: geo[a])
                }
            case .pin:
                if let a = anchors[.pin] {
                    pointer(at: geo[a])
                }
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }

    /// La mano toca el centro del control real (el anillo del gesto está a (-14, -26) del centro).
    private func pointer(at rect: CGRect) -> some View {
        HandGestureHint(gesture: .tap)
            .position(x: rect.midX + 14, y: rect.midY + 26)
    }

    // MARK: Momento de valor

    private var valueCard: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(FrameStudioBrand.accent)
                    .accessibilityHidden(true)
                Text(valueTitle)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("\(MeasureFormat.size(width: widthCentimeters, height: heightCentimeters)), tamaño real. Hazlo con cualquier obra antes de colgarla o venderla.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Analytics.log(.demoValueCTA(cta: "start_gallery"))
                    send(.continueTapped)
                    finish(.startGallery)
                } label: {
                    Text("Empezar mi galería").frame(maxWidth: .infinity, minHeight: 44)
                }
                .primaryButtonStyle()
                Button {
                    Analytics.log(.demoValueCTA(cta: "try_another"))
                    finish(.tryAnother)
                } label: {
                    Text("Probar con otra obra").frame(maxWidth: .infinity, minHeight: 44)
                }
                .secondaryGlassButtonStyle()
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var valueTitle: String {
        switch (guide.mode, isOwnArtwork) {
        case (.ar, true): return "Así se ve tu obra en tu pared"
        case (.ar, false): return "Así se vería en tu pared"
        case (.simulated, true): return "Así se ve tu obra colgada"
        case (.simulated, false): return "Así se ve colgada, a tamaño real"
        }
    }

    // MARK: Lógica

    private func send(_ event: DemoGuideEvent) {
        let previous = guide.step
        guard guide.handle(event) else { return }
        if event == .skip {
            Analytics.log(.demoGuideSkipped(step: previous.analyticsName))
        }
        Analytics.log(.demoGuideStep(step: guide.step.analyticsName, mode: guide.mode.rawValue))
    }

    /// «Ajá»: la obra lleva 3 s fijada con la app activa (y, en AR, la escena a la vista).
    private func startAhaTimer() {
        ahaTask?.cancel()
        ahaTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(DemoGuide.ahaSeconds))
            guard !Task.isCancelled, placement.phase == .pinned, scenePhase == .active,
                  guide.step == .explore else { return }
            Analytics.log(.demoAhaReached(
                mode: guide.mode.rawValue,
                elapsedSeconds: Date.now.timeIntervalSince(startedAt),
                ownArtwork: isOwnArtwork
            ))
            send(.ahaReached)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func prepare() async {
        Analytics.log(.demoGuideStep(step: guide.step.analyticsName, mode: guide.mode.rawValue))
        guard guide.mode == .ar else { startSimulatedWall(); return }
        // La cámara se pide aquí, al empezar la prueba (ya no hay pantalla de permisos).
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            Analytics.log(.permissionResult(kind: "camera", granted: granted))
            guard granted else { fallBack(reason: "camera_denied"); return }
        }
        let demo = ArtworkPiece(
            title: title,
            widthCentimeters: widthCentimeters,
            heightCentimeters: heightCentimeters,
            kind: .paintingPhoto
        )
        do {
            demo.imageFileName = try ArtworkFileStore.saveJPEG(image, for: demo.id)
            piece = demo
            startWallTimeout()
        } catch {
            fallBack(reason: "image_save_failed")
        }
    }

    private func startWallTimeout() {
        wallTimeoutTask?.cancel()
        wallTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(DemoGuide.wallTimeoutSeconds))
            guard !Task.isCancelled, guide.mode == .ar, placement.phase == .searching else { return }
            offerSampleWall = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func fallBack(reason: String) {
        guard guide.mode == .ar else { return }
        Analytics.log(.demoFallback(reason: reason))
        wallTimeoutTask?.cancel()
        offerSampleWall = false
        if let piece { ArtworkFileStore.deleteFiles(forID: piece.id) }
        piece = nil
        guide.fallBackToSimulated()
        if guide.step == .pin || guide.step == .explore {
            // Venía de AR con la obra colocada: en la pared de ejemplo se empieza a colocar de nuevo.
            guide = { var g = DemoGuide(mode: .simulated); g.handle(.paintingChosen); return g }()
        }
        placement = ARPlacementState()
        startSimulatedWall()
        Analytics.log(.demoGuideStep(step: guide.step.analyticsName, mode: guide.mode.rawValue))
    }

    /// Pared de ejemplo: maneja el mismo `ARPlacementState` que el coordinador AR.
    private func startSimulatedWall() {
        let state = placement
        state.phase = .searching
        state.canPlace = false
        state.message = measuringCopy
        func becomeReady() {
            simReadyTask?.cancel()
            simReadyTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled, state.phase == .searching else { return }
                state.canPlace = true
                state.message = readyCopy
            }
        }
        state.placeHandler = {
            guard state.canPlace else { return }
            state.canPlace = false
            state.phase = .aiming
            state.message = placedCopy
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        state.pinHandler = {
            state.phase = .pinned
            state.message = pinnedCopy
        }
        state.unpinHandler = {
            state.phase = .aiming
            state.message = placedCopy
        }
        state.moveHandler = {
            state.phase = .searching
            state.canPlace = false
            state.message = measuringCopy
            becomeReady()
        }
        state.snapshotHandler = nil
        becomeReady()
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "DemoAutoplay") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4)); state.place()
                try? await Task.sleep(for: .seconds(4)); state.pin()
            }
        }
        #endif
    }

    private func cleanup() {
        ahaTask?.cancel()
        wallTimeoutTask?.cancel()
        simReadyTask?.cancel()
        if let piece { ArtworkFileStore.deleteFiles(forID: piece.id) }
    }

    private func finish(_ outcome: DemoOutcome) {
        cleanup()
        onFinish(outcome)
    }
}

private struct StepDots: View {
    let current: DemoGuideStep
    let mode: DemoGuide.Mode

    private var steps: [DemoGuideStep] {
        mode == .ar ? [.scanWall, .tapToPlace, .pin, .explore] : [.tapToPlace, .pin, .explore]
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(steps, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= current.rawValue ? FrameStudioBrand.accent : FrameStudioBrand.softLavender)
                    .frame(width: step == current ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paso \((steps.firstIndex(of: current) ?? steps.count - 1) + 1) de \(steps.count)")
    }
}

/// Pared de ejemplo a escala: pared de 320 cm de ancho, zócalo, suelo y sofá de 200 cm como referencia.
/// Colocada: la obra se ve semitransparente con contorno (como el «fantasma» de AR); fijada: opaca.
struct SampleWallScene: View {
    let image: UIImage
    let widthCentimeters: Double
    let heightCentimeters: Double
    let phase: ARPlacementState.Phase

    private let wallWidthCentimeters: Double = 320
    private let sofaWidthCentimeters: Double = 200

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / wallWidthCentimeters
            let floorY = geo.size.height * 0.80
            let sofaWidth = sofaWidthCentimeters * scale
            let artW = widthCentimeters * scale
            let artH = heightCentimeters * scale
            // Centro de la obra a ~ 150 cm del suelo (altura de museo).
            let artCenterY = floorY - 150 * scale
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.90, blue: 0.85), Color(red: 0.86, green: 0.82, blue: 0.76)],
                    startPoint: .top, endPoint: .bottom
                )
                // Luz de pared suave.
                RadialGradient(colors: [.white.opacity(0.35), .clear], center: .init(x: 0.5, y: 0.25),
                               startRadius: 10, endRadius: geo.size.width)
                // Suelo de madera y zócalo.
                Rectangle()
                    .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.40, blue: 0.28), Color(red: 0.42, green: 0.30, blue: 0.21)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: geo.size.height - floorY)
                    .position(x: geo.size.width / 2, y: floorY + (geo.size.height - floorY) / 2)
                Rectangle().fill(.white.opacity(0.9))
                    .frame(height: max(4, 10 * scale))
                    .position(x: geo.size.width / 2, y: floorY - max(2, 5 * scale))
                Image(systemName: "sofa.fill")
                    .resizable().scaledToFit()
                    .frame(width: sofaWidth)
                    .foregroundStyle(Color(red: 0.36, green: 0.42, blue: 0.52))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
                    .position(x: geo.size.width / 2, y: floorY - sofaWidth * 0.22)
                    .accessibilityLabel("Sofá de 2 metros de referencia")
                if phase == .aiming || phase == .pinned {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: artW, height: artH).clipped()
                        .padding(max(3, 2.5 * scale)).background(Color.white)
                        .opacity(phase == .pinned ? 1 : 0.82)
                        .overlay {
                            if phase == .aiming {
                                Rectangle().strokeBorder(.white, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            }
                        }
                        .shadow(color: .black.opacity(phase == .pinned ? 0.35 : 0.15), radius: phase == .pinned ? 12 : 4, y: phase == .pinned ? 8 : 2)
                        .position(x: geo.size.width / 2, y: artCenterY)
                        .transition(.opacity)
                        .accessibilityLabel(phase == .pinned ? "Obra fijada en la pared" : "Obra colocada, sin fijar")
                } else {
                    // Retícula de búsqueda como en AR.
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .frame(width: artW, height: artH)
                        .position(x: geo.size.width / 2, y: artCenterY)
                        .accessibilityHidden(true)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: phase)
        }
    }
}

/// Vista previa de lo que recibe el cliente por WhatsApp.
struct ClientLinkPreview: View {
    let image: UIImage
    let title: String
    let widthCentimeters: Double
    var onContinue: () -> Void

    private var link: String {
        let slug = ArtistProfile.shared.slug.isEmpty ? "tu-estudio" : ArtistProfile.shared.slug
        return "frame-studio.netlify.app/\(slug)/\(ArtistProfile.makeSlug(from: title))"
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Esto recibe tu cliente")
                .font(.title3.weight(.bold))
                .padding(.top, 24)
            VStack(alignment: .leading, spacing: 0) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(height: 200).frame(maxWidth: .infinity).clipped()
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text("Ver en mi pared · \(Int(widthCentimeters.rounded())) cm").font(.footnote).foregroundStyle(.secondary)
                    Text(link).font(.caption).foregroundStyle(FrameStudioBrand.blue).lineLimit(1)
                }
                .padding(12)
            }
            .background(FrameStudioBrand.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .padding(.horizontal, 24)
            Text("Lo abre en el navegador y cuelga la obra en su pared con la cámara. No tiene que instalar nada.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            OnboardingPrimaryButton(title: "Continuar", action: onContinue)
                .padding(.bottom, 24)
        }
        .background(FrameStudioBrand.canvas.ignoresSafeArea())
    }
}
