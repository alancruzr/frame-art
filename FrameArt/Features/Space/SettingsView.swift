import SwiftUI
import UserNotifications

/// Ajustes (Form del sistema): estudio, Pro, avisos, unidades e información legal.
struct SettingsView: View {
    @State private var profile = ArtistProfile.shared
    @State private var subscriptions = SubscriptionManager.shared
    @State private var studioName = ArtistProfile.shared.displayName
    @State private var showPaywall = false
    @State private var restoring = false
    @State private var restoreMessage: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @AppStorage(MeasureUnit.storageKey) private var unit: MeasureUnit = .centimeters
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    static let privacyURL = URL(string: "https://frame-studio.netlify.app/privacy/")!
    static let termsURL = URL(string: "https://frame-studio.netlify.app/terms/")!
    static let supportURL = URL(string: "https://frame-studio.netlify.app/support/")!
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        NavigationStack {
            Form {
                studioSection
                proSection
                notificationsSection
                Section("Medidas") {
                    Picker("Unidad", selection: $unit) {
                        Text("Centímetros").tag(MeasureUnit.centimeters)
                        Text("Pulgadas").tag(MeasureUnit.inches)
                    }
                }
                Section("Información") {
                    Link(destination: Self.privacyURL) { Label("Política de privacidad", systemImage: "hand.raised") }
                    Link(destination: Self.termsURL) { Label("Términos de uso", systemImage: "doc.text") }
                    Link(destination: Self.supportURL) { Label("Soporte", systemImage: "questionmark.circle") }
                    LabeledContent("Versión", value: Self.versionString)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { saveStudio(); dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(source: .settings) { showPaywall = false }
            }
            .alert("Restaurar compras", isPresented: Binding(
                get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
            .task { await refreshNotificationStatus() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await refreshNotificationStatus() }
            }
        }
    }

    // MARK: Secciones

    private var studioSection: some View {
        Section {
            TextField("Nombre del estudio", text: $studioName)
                .textContentType(.organizationName)
                .submitLabel(.done)
                .onSubmit(saveStudio)
            if !profile.slug.isEmpty {
                LabeledContent("Enlace", value: "…/\(profile.slug)/")
            }
        } header: {
            Text("Estudio")
        } footer: {
            Text("El enlace no cambia al renombrar el estudio, así los enlaces enviados siguen funcionando.")
        }
    }

    private var proSection: some View {
        Section {
            LabeledContent("Plan", value: subscriptions.isPro ? "Pro" : "Gratis")
            if subscriptions.isPro {
                Button {
                    openURL(subscriptions.managementURL ?? Self.manageSubscriptionsURL)
                } label: {
                    Label("Gestionar suscripción", systemImage: "creditcard")
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label("Ver Frame Studio Pro", systemImage: "sparkles")
                }
            }
            Button {
                Task { await restore() }
            } label: {
                if restoring {
                    ProgressView()
                } else {
                    Label("Restaurar compras", systemImage: "arrow.clockwise")
                }
            }
            .disabled(restoring)
        } header: {
            Text("Frame Studio Pro")
        }
    }

    private var notificationsSection: some View {
        Section {
            LabeledContent("Avisos", value: notificationStatusText)
            if notificationStatus == .notDetermined {
                Button {
                    Task {
                        await PushNotifications.shared.requestAuthorization()
                        await refreshNotificationStatus()
                    }
                } label: {
                    Label("Activar avisos", systemImage: "bell.badge")
                }
            } else {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                } label: {
                    Label("Cambiar en Configuración", systemImage: "gear")
                }
            }
        } header: {
            Text("Avisos")
        } footer: {
            Text("Te avisamos cuando un cliente abre el enlace de una obra (como mucho uno cada 30 minutos por obra).")
        }
    }

    // MARK: Lógica

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "Activados"
        case .denied: "Desactivados"
        default: "Sin configurar"
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func saveStudio() {
        let name = studioName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != profile.displayName else { return }
        profile.save(displayName: name, slug: profile.slug)
    }

    private func restore() async {
        restoring = true
        defer { restoring = false }
        let ok = await subscriptions.restore()
        restoreMessage = ok ? "Listo: Frame Studio Pro está activo." : (subscriptions.errorMessage ?? "No se pudieron restaurar las compras.")
    }

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
