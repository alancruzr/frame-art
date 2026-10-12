import Foundation
import UserNotifications

/// Recordatorios locales "comparte una obra" en los días elegidos en el onboarding.
/// Equivalente al compromiso de creador de Clarity (días + hora + recordatorios opcionales).
@MainActor
final class SharingReminders {
    static let shared = SharingReminders()
    static let identifierPrefix = "framestudio.sharing."
    static let weekdaysKey = "sharingReminderWeekdays"

    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Pide permiso solo si aún no se decidió. Devuelve si quedó autorizado.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            Analytics.log(.permissionResult(kind: "notifications", granted: granted))
            return granted
        default:
            return false
        }
    }

    func configure(weekdays: Set<Int>, hour: Int, minute: Int, enabled: Bool) async {
        let ids = (1...7).map { Self.identifierPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        UserDefaults.standard.set(Array(weekdays).sorted(), forKey: Self.weekdaysKey)
        guard enabled, !weekdays.isEmpty, await requestAuthorizationIfNeeded() else { return }

        for weekday in weekdays.sorted() {
            let content = UNMutableNotificationContent()
            content.title = "Hoy toca compartir una obra"
            content.body = "Elige una pieza y mándale el enlace a un cliente. La verá en su pared, a tamaño real."
            content.sound = .default
            var date = DateComponents()
            date.weekday = weekday
            date.hour = hour
            date.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + String(weekday),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
