import SwiftUI
import UIKit

/// Controles reales que se señalan en la prueba guiada (la mano apunta a su posición).
enum PlacementControlID: Hashable {
    case place, pin
}

struct PlacementControlAnchorKey: PreferenceKey {
    static let defaultValue: [PlacementControlID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [PlacementControlID: Anchor<CGRect>], nextValue: () -> [PlacementControlID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Botón Fijar compartido por la vista AR de la app y la prueba del onboarding.
/// Sin fijar: «Fijar» (cristal, contorno). Fijada: «Fijada» relleno con el acento, háptico
/// de éxito y un pulso sutil (sin pulso con Reducir movimiento). Tocar «Fijada» la desfija.
struct FijarButton: View {
    let isPinned: Bool
    let pin: () -> Void
    let unpin: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Group {
            if isPinned {
                Button(action: unpin) { label }
                    .primaryButtonStyle()
            } else {
                Button(action: pin) { label }
                    .secondaryGlassButtonStyle()
                    .tint(FrameStudioBrand.accent)
            }
        }
        .scaleEffect(pulse ? 1.06 : 1)
        .sensoryFeedback(trigger: isPinned) { _, pinned in
            pinned ? .success : .impact(weight: .light)
        }
        .onChange(of: isPinned) { _, pinned in
            guard pinned, !reduceMotion else { return }
            withAnimation(.spring(duration: 0.25)) { pulse = true }
            withAnimation(.spring(duration: 0.35).delay(0.2)) { pulse = false }
        }
        .accessibilityLabel(isPinned ? "Fijada" : "Fijar")
        .accessibilityHint(isPinned ? "Toca para soltarla y moverla" : "Deja la obra fija en la pared")
        .accessibilityAddTraits(isPinned ? .isSelected : [])
        .anchorPreference(key: PlacementControlAnchorKey.self, value: .bounds) { [.pin: $0] }
    }

    private var label: some View {
        Label(isPinned ? "Fijada" : "Fijar", systemImage: isPinned ? "pin.fill" : "pin")
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentTransition(.symbolEffect(.replace))
    }
}

/// Barra de controles de colocación (Colocar aquí / Mover / Fijar / foto), igual en app y prueba.
struct PlacementControls: View {
    var placement: ARPlacementState
    var showsShutter = true
    var onSnapshot: (UIImage) -> Void = { _ in }
    @State private var isCapturing = false

    var body: some View {
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
            .anchorPreference(key: PlacementControlAnchorKey.self, value: .bounds) { [.place: $0] }
            .padding()
        case .aiming, .pinned:
            let pinned = placement.phase == .pinned
            HStack(spacing: 12) {
                Button {
                    placement.move()
                } label: {
                    Text(pinned ? "Mover a otra pared" : "Mover")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .secondaryGlassButtonStyle()
                FijarButton(isPinned: pinned, pin: { placement.pin() }, unpin: { placement.unpin() })
                if showsShutter { shutterButton }
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
                    onSnapshot(image)
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

/// Capa sobre la escena: etiqueta de tamaño real arriba, guía opcional, mensaje de estado y controles.
struct ARPlacementOverlay<Guidance: View>: View {
    var placement: ARPlacementState
    let widthCentimeters: Double
    let heightCentimeters: Double
    var showsShutter = true
    var showsMessage = true
    var onSnapshot: (UIImage) -> Void = { _ in }
    @ViewBuilder var guidance: () -> Guidance

    var body: some View {
        VStack(spacing: 8) {
            if placement.phase == .aiming || placement.phase == .pinned {
                TrueSizeLabel(widthCentimeters: widthCentimeters, heightCentimeters: heightCentimeters)
                    .padding(.top, 8)
            }
            Spacer()
            guidance()
            if showsMessage, let message = placement.message {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
            }
            PlacementControls(placement: placement, showsShutter: showsShutter, onSnapshot: onSnapshot)
        }
    }
}

extension ARPlacementOverlay where Guidance == EmptyView {
    init(placement: ARPlacementState, widthCentimeters: Double, heightCentimeters: Double,
         showsShutter: Bool = true, onSnapshot: @escaping (UIImage) -> Void = { _ in }) {
        self.init(placement: placement, widthCentimeters: widthCentimeters, heightCentimeters: heightCentimeters,
                  showsShutter: showsShutter, onSnapshot: onSnapshot) { EmptyView() }
    }
}
