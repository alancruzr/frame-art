import SwiftUI

/// Se muestra si SwiftData no puede abrir la base de datos (en lugar de cerrar la app).
struct StorageErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onReset: () -> Void
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle).imageScale(.large)
                .foregroundStyle(FrameStudioBrand.accent)
            Text("No se pudieron abrir tus obras")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Tus fotos siguen en el dispositivo. Puedes reintentar o restablecer la base de datos (se guarda una copia de seguridad).")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar", action: onRetry)
                .primaryButtonStyle()
            ShareLink(item: message) {
                Label("Compartir diagnóstico", systemImage: "square.and.arrow.up")
            }
            Button("Restablecer…", role: .destructive) { confirmReset = true }
        }
        .padding(32)
        .confirmationDialog("¿Restablecer la base de datos?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Restablecer y guardar copia", role: .destructive, action: onReset)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se crea una base vacía. La anterior se guarda como copia de seguridad.")
        }
    }
}

#Preview {
    StorageErrorView(message: "error", onRetry: {}, onReset: {})
}
