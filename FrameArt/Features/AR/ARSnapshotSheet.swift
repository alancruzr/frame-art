import SwiftUI

/// Foto de la obra colgada en la pared, lista para compartir (con el enlace si está publicada).
struct ARSnapshotSheet: View {
    let image: UIImage
    let title: String
    let link: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("Foto de \(title) en la pared")
                ShareLink(
                    item: Image(uiImage: image),
                    message: Text(shareMessage),
                    preview: SharePreview(title, image: Image(uiImage: image))
                ) {
                    Label("Compartir foto", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                if link == nil {
                    Text("Publica la obra para incluir el enlace y que tu cliente la vea en su pared.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Foto en la pared")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private var shareMessage: String {
        if let link { return "Así queda \(title) en la pared. Pruébala en la tuya: \(link.absoluteString)" }
        return "Así queda \(title) en la pared."
    }
}
