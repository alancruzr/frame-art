import ARKit
import AVFoundation
import SwiftUI
import UIKit

/// Prueba guiada: AR real en el dispositivo (o pared simulada como respaldo), con una mano
/// animada por paso que avanza sola cuando ocurre el evento real.
struct GuidedDemoView: View {
    let image: UIImage
    let widthCentimeters: Double
    let heightCentimeters: Double
    let title: String
    var onFinish: () -> Void

    @State private var guide: DemoGuide
    @State private var placement = ARPlacementState()
    @State private var piece: ArtworkPiece?
    @State private var showClientPreview = false
    // Pared simulada
    @State private var simPlaced = false
    @State private var simOffset: CGSize = .zero
    @State private var simDragBase: CGSize = .zero
    @State private var lastAdjust = 0

    init(image: UIImage, widthCentimeters: Double, heightCentimeters: Double, title: String, onFinish: @escaping () -> Void) {
        self.image = image
        self.widthCentimeters = widthCentimeters
        self.heightCentimeters = heightCentimeters
        self.title = title
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
            overlay
                // La capa va sobre la cámara: crece con Dynamic Type pero sin tapar la escena.
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .preferredColorScheme(.dark)
        .task { await prepare() }
        .onDisappear { cleanup() }
        .onChange(of: placement.canPlace) { _, ready in
            // Al colocar, `canPlace` también pasa a false: eso no es "pared perdida".
            if ready {
                send(.wallDetected)
            } else if placement.phase == .searching {
                send(.wallLost)
            }
        }
        .onChange(of: placement.phase) { _, phase in
            if phase == .aiming { send(.placed) }
            if phase == .failed { fallBack() }
        }
        .onChange(of: placement.adjustCount) { _, _ in send(.adjusted) }
        .sheet(isPresented: $showClientPreview) {
            ClientLinkPreview(image: image, title: title, widthCentimeters: widthCentimeters) {
                showClientPreview = false
                finish()
            }
            .presentationDetents([.large])
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
                    .overlay(alignment: .top) {
                        if placement.phase != .searching {
                            TrueSizeLabel(widthCentimeters: widthCentimeters, heightCentimeters: heightCentimeters)
                                .padding(.top, 64)
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }
            #endif
        } else {
            simulatedWall
        }
    }

    private var simulatedWall: some View {
        GeometryReader { geo in
            let scale = geo.size.width / 320
            let w = widthCentimeters * scale
            let h = heightCentimeters * scale
            ZStack {
                LinearGradient(colors: [FrameStudioBrand.softLavender, FrameStudioBrand.softBlue], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                Image(systemName: "sofa.fill")
                    .resizable().scaledToFit()
                    .frame(width: 200 * scale)
                    .foregroundStyle(FrameStudioBrand.accent.opacity(0.35))
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.72)
                if simPlaced {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: w, height: h).clipped()
                        .padding(5).background(Color.white)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
                        .position(x: geo.size.width / 2 + simOffset.width, y: geo.size.height * 0.42 + simOffset.height)
                        .gesture(simAdjustGesture)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    TrueSizeLabel(widthCentimeters: widthCentimeters, heightCentimeters: heightCentimeters)
                        .position(x: geo.size.width / 2 + simOffset.width, y: geo.size.height * 0.42 + simOffset.height + h / 2 + 26)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !simPlaced, guide.step == .tapToPlace else { return }
                withAnimation(.spring(duration: 0.35)) { simPlaced = true }
                send(.placed)
            }
        }
    }

    private var simAdjustGesture: some Gesture {
        DragGesture()
            .onChanged { simOffset = CGSize(width: simDragBase.width + $0.translation.width, height: simDragBase.height + $0.translation.height) }
            .onEnded { _ in simDragBase = simOffset; markSimAdjusted() }
    }

    private func markSimAdjusted() {
        lastAdjust += 1
        send(.adjusted)
    }

    // MARK: Capa de instrucciones

    private var overlay: some View {
        VStack(spacing: 0) {
            HStack {
                Text(guide.mode == .ar ? "Prueba en tu pared" : "Prueba en una pared de ejemplo")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button("Saltar prueba") {
                    Analytics.log(.demoGuideSkipped(step: guide.step.analyticsName))
                    finish()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)
            .background(.black.opacity(0.25))

            Spacer()

            if let hint = handGesture {
                HandGestureHint(gesture: hint)
                    .allowsHitTesting(false)
                    .padding(.bottom, 12)
            }

            VStack(spacing: 12) {
                StepDots(current: guide.step, mode: guide.mode)
                Text(instruction)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if guide.mode == .ar, let message = placement.message, guide.step == .scanWall {
                    Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                actions
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var handGesture: HandGestureHint.Gesture? {
        switch guide.step {
        case .scanWall: return .scan
        case .tapToPlace: return .tap
        case .adjust: return .drag
        case .share: return .tap
        default: return nil
        }
    }

    private var instruction: String {
        switch (guide.step, guide.mode) {
        case (.scanWall, _): return "Apunta a una pared y mueve el teléfono despacio de lado a lado."
        case (.tapToPlace, .ar): return "Pared lista. Toca «Colocar aquí» para colgar la obra a tamaño real."
        case (.tapToPlace, .simulated): return "Toca la pared para colgar la obra."
        case (.adjust, _): return "Arrastra para moverla. El tamaño es el real: no cambia."
        case (.share, _): return "Toca «Compartir» para ver el enlace que recibe tu cliente."
        default: return "Listo."
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch guide.step {
        case .tapToPlace where guide.mode == .ar:
            Button { placement.place() } label: {
                Text("Colocar aquí").frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
            .disabled(!placement.canPlace)
        case .share:
            Button {
                send(.shareTapped)
                showClientPreview = true
            } label: {
                Label("Compartir", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryButtonStyle()
        case .scanWall, .tapToPlace, .adjust:
            Button("Siguiente paso") { send(.skip) }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
        default:
            EmptyView()
        }
    }

    // MARK: Lógica

    private func send(_ event: DemoGuideEvent) {
        let previous = guide.step
        guard guide.handle(event) else { return }
        if event == .skip {
            Analytics.log(.demoGuideSkipped(step: previous.analyticsName))
            // Saltar la colocación en el simulado deja la obra puesta para poder ajustarla.
            if guide.mode == .simulated, guide.step == .adjust, !simPlaced { simPlaced = true }
        }
        UIImpactFeedbackGenerator(style: guide.step == .finished ? .heavy : .medium).impactOccurred()
        Analytics.log(.demoGuideStep(step: guide.step.analyticsName, mode: guide.mode.rawValue))
    }

    private func prepare() async {
        Analytics.log(.demoGuideStep(step: guide.step.analyticsName, mode: guide.mode.rawValue))
        guard guide.mode == .ar else { return }
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            Analytics.log(.permissionResult(kind: "camera", granted: granted))
            guard granted else { fallBack(); return }
        }
        let demo = ArtworkPiece(
            title: title,
            widthCentimeters: widthCentimeters,
            heightCentimeters: heightCentimeters,
            kind: .paintingPhoto
        )
        do {
            demo.imageFileName = try ArtworkFileStore.saveJPEG(image, for: demo.id)
            placement.allowsAdjusting = true
            piece = demo
        } catch {
            fallBack()
        }
    }

    private func fallBack() {
        guard guide.mode == .ar else { return }
        guide.fallBackToSimulated()
        Analytics.log(.demoGuideStep(step: guide.step.analyticsName, mode: guide.mode.rawValue))
    }

    private func cleanup() {
        if let piece { ArtworkFileStore.deleteFiles(forID: piece.id) }
    }

    private func finish() {
        cleanup()
        onFinish()
    }
}

private struct StepDots: View {
    let current: DemoGuideStep
    let mode: DemoGuide.Mode

    private var steps: [DemoGuideStep] {
        mode == .ar ? [.scanWall, .tapToPlace, .adjust, .share] : [.tapToPlace, .adjust, .share]
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
