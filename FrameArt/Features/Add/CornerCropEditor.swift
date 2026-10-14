import SwiftUI

/// Editor manual de 4 esquinas sobre la foto original (HIG Photo editing: vista previa y
/// confirmar al descartar cambios).
struct CornerCropEditor: View {
    let image: UIImage
    let onApply: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var quad: CornerQuad
    @State private var initial: CornerQuad
    @State private var confirmDiscard = false
    @State private var applying = false
    @State private var failed = false

    private let names = ["superior izquierda", "superior derecha", "inferior derecha", "inferior izquierda"]

    init(image: UIImage, initialQuad: CornerQuad?, onApply: @escaping (UIImage) -> Void) {
        let upright = image.normalizedUpright()
        self.image = upright
        self.onApply = onApply
        let q = initialQuad ?? .inset
        _quad = State(initialValue: q)
        _initial = State(initialValue: q)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                GeometryReader { geo in
                    let frame = fittedRect(in: geo.size)
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX, y: frame.minY)
                            .accessibilityHidden(true)
                        quadPath(in: frame)
                            .fill(Color.black.opacity(0.35), style: FillStyle(eoFill: true))
                            .allowsHitTesting(false)
                        quadOutline(in: frame)
                            .stroke(FrameStudioBrand.accent, lineWidth: 2)
                            .allowsHitTesting(false)
                        ForEach(0..<4, id: \.self) { index in
                            handle(index: index, frame: frame)
                        }
                    }
                }
                .padding(.horizontal)
                Text("Arrastra cada esquina al borde del lienzo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Ajustar esquinas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        if quad != initial { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { apply() }
                        .disabled(applying)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Restablecer", systemImage: "arrow.counterclockwise") { quad = initial }
                        .disabled(quad == initial)
                }
            }
            .confirmationDialog("¿Descartar los cambios del recorte?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Descartar cambios", role: .destructive) { dismiss() }
                Button("Seguir editando", role: .cancel) {}
            }
            .alert("No se pudo recortar", isPresented: $failed) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text("Las esquinas forman una figura no válida. Sepáralas un poco más e inténtalo otra vez.")
            }
            .interactiveDismissDisabled(quad != initial)
        }
    }

    private func handle(index: Int, frame: CGRect) -> some View {
        let p = quad[index]
        return Circle()
            .fill(.white)
            .overlay(Circle().stroke(FrameStudioBrand.accent, lineWidth: 3))
            .frame(width: 26, height: 26)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .position(x: frame.minX + p.x * frame.width, y: frame.minY + p.y * frame.height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        quad[index] = CGPoint(
                            x: (value.location.x - frame.minX) / frame.width,
                            y: (value.location.y - frame.minY) / frame.height
                        )
                    }
                    .onEnded { _ in UISelectionFeedbackGenerator().selectionChanged() }
            )
            .accessibilityElement()
            .accessibilityLabel("Esquina \(names[index])")
            .accessibilityAdjustableAction { direction in
                // VoiceOver: desliza arriba/abajo para acercar o alejar la esquina del centro.
                let center = CGPoint(x: 0.5, y: 0.5)
                let step: CGFloat = direction == .increment ? 0.02 : -0.02
                let dx = p.x - center.x, dy = p.y - center.y
                quad[index] = CGPoint(x: p.x + (dx >= 0 ? step : -step), y: p.y + (dy >= 0 ? step : -step))
            }
    }

    private func quadOutline(in frame: CGRect) -> Path {
        Path { path in
            let pts = quad.points.map { CGPoint(x: frame.minX + $0.x * frame.width, y: frame.minY + $0.y * frame.height) }
            path.addLines(pts)
            path.closeSubpath()
        }
    }

    private func quadPath(in frame: CGRect) -> Path {
        var path = Path(frame)
        path.addPath(quadOutline(in: frame))
        return path
    }

    private func fittedRect(in size: CGSize) -> CGRect {
        let aspect = image.size.width / max(image.size.height, 1)
        var w = size.width, h = size.width / aspect
        if h > size.height { h = size.height; w = h * aspect }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    private func apply() {
        applying = true
        let image = image, quad = quad
        Task {
            let result = await Task.detached { PaintingCanvasCropper.perspectiveCrop(image, quad: quad) }.value
            applying = false
            if let result {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onApply(result)
                dismiss()
            } else {
                failed = true
            }
        }
    }
}
