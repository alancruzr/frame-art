import Foundation
import OSLog
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Configura Firebase solo si `GoogleService-Info.plist` está en el bundle (lo copia una fase
/// de build desde `Config/`, en .gitignore). Sin el plist la app funciona y solo registra en el log.
/// Igual que Clarity: FirebaseAnalyticsCore (sin IDFA ni AdSupport) y Crashlytics apagado en
/// DEBUG y simulador.
@MainActor
enum FirebaseTelemetry {
    private static let logger = Logger(subsystem: "app.framestudio.ios", category: "Firebase")
    private(set) static var isConfigured = false

    static func configureIfAvailable(bundle: Bundle = .main) {
        #if canImport(FirebaseCore)
        guard !isConfigured else { return }
        guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            logger.info("Firebase skipped: GoogleService-Info.plist not in bundle")
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isConfigured = true
        #if canImport(FirebaseAnalytics)
        Analytics.sinks.append { event in
            FirebaseAnalytics.Analytics.logEvent(event.name, parameters: event.parameters)
        }
        #endif
        #if canImport(FirebaseCrashlytics)
        #if DEBUG || targetEnvironment(simulator)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(
            UserDefaults.standard.bool(forKey: "FrameStudioCrashReportingEnabled")
        )
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
        Analytics.sinks.append { event in
            Crashlytics.crashlytics().log(event.name)
        }
        ErrorReporter.sinks.append { error, context in
            Crashlytics.crashlytics().record(error: error, userInfo: ["context": context])
        }
        #endif
        logger.info("Firebase configured")
        #endif
    }
}
