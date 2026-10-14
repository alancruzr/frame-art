import CoreImage.CIFilterBuiltins
import SwiftUI

/// "Publicada · N vistas": estado de publicación de una obra.
struct PublishedBadge: View {
    let count: Int?

    var body: some View {
        Label(text, systemImage: "link")
            .font(.caption.weight(.semibold))
            .foregroundStyle(FrameStudioBrand.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FrameStudioBrand.accent.opacity(0.14), in: Capsule())
            .accessibilityLabel(text)
    }

    private var text: String { ViewCounter.badge(count) }
}

/// Código QR del enlace, para mostrarlo en una feria o estudio.
enum QRCode {
    static func image(for url: URL, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct QRCodeSheet: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = QRCode.image(for: url) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(maxWidth: 320)
                        .accessibilityLabel("Código QR del enlace de \(title)")
                }
                Text("Tu cliente escanea con la cámara y ve la obra en su pared.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text(url.absoluteString)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }
}
