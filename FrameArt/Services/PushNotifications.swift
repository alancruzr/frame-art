import Foundation
import OSLog
import UIKit
import UserNotifications

/// Avisos "tu cliente abrió la obra". Se piden en contexto, tras el primer envío correcto.
@MainActor
final class PushNotifications: NSObject {
    static let shared = PushNotifications()
    static let promptedKey = "pushPermissionPrompted"

    private let logger = Logger(subsystem: "app.framestudio.ios", category: "Push")
    private let center = UNUserNotificationCenter.current()

    /// Solo una vez, y solo si el sistema aún no decidió.
    func shouldPrompt() async -> Bool {
        guard !UserDefaults.standard.bool(forKey: Self.promptedKey) else { return false }
        return await center.notificationSettings().authorizationStatus == .notDetermined
    }

    func markPrompted() {
        UserDefaults.standard.set(true, forKey: Self.promptedKey)
        Analytics.log(.pushPermissionPrompted)
    }

    func requestAuthorization() async {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            Analytics.log(.pushPermissionGranted)
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// En cada arranque: si ya hay permiso, vuelve a registrar (el token puede cambiar).
    func registerIfAuthorized() async {
        let status = await center.notificationSettings().authorizationStatus
        if status == .authorized || status == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        let studio = ArtistProfile.shared.slug
        guard !studio.isEmpty else { return }
        Task { await upload(token: hex, studio: studio) }
    }

    private func upload(token: String, studio: String) async {
        guard let url = URL(string: ClientViewer.origin)?.appendingPathComponent("api/devices/push-token") else { return }
        do {
            let bearer = try await DeviceAuth.shared.bearer(for: studio)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            #if DEBUG
            let environment = "sandbox"
            #else
            let environment = "production"
            #endif
            request.httpBody = try JSONSerialization.data(withJSONObject: ["token": token, "environment": environment])
            let (_, response) = try await URLSession.shared.data(for: request)
            logger.info("push token upload status \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        } catch {
            // Sin App Attest (simulador) o servidor sin configurar: no hay avisos, la app sigue igual.
            logger.info("push token upload skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Enlace de la obra a partir del payload {studio, artwork}.
    nonisolated static func artworkURL(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let studio = userInfo["studio"] as? String, let artwork = userInfo["artwork"] as? String,
              !studio.isEmpty, !artwork.isEmpty else { return nil }
        return URL(string: "\(ClientViewer.origin)/\(studio)/\(artwork)/")
    }
}

/// Recibe el token APNs y los toques en avisos.
final class FrameStudioAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in await PushNotifications.shared.registerIfAuthorized() }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushNotifications.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let url = PushNotifications.artworkURL(from: response.notification.request.content.userInfo)
        completionHandler()
        guard let url else { return }
        Task { @MainActor in
            Analytics.log(.clientLinkOpenedNotificationTapped)
            DeepLinkRouter.shared.pendingURL = url
        }
    }
}
