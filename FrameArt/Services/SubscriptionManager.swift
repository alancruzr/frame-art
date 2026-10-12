import Foundation
import Observation
import OSLog
import RevenueCat

/// Identificadores y límites de la suscripción. Mismo esquema que Clarity: una oferta `default`,
/// una entitlement única y paquetes mensual / anual / de por vida.
enum ProPlan {
    static let entitlementID = "pro"
    static let offeringID = "default"
    static let monthlyProductID = "app.framestudio.ios.pro.monthly"
    static let annualProductID = "app.framestudio.ios.pro.annual"
    static let lifetimeProductID = "app.framestudio.ios.pro.lifetime"

    /// Obras publicadas a la vez sin Pro. Configurable sin recompilar con la clave
    /// `FreePublishedLimit` de UserDefaults (p. ej. `-FreePublishedLimit 5` como argumento de arranque).
    static let defaultFreePublishedLimit = 3
    static var freePublishedLimit: Int {
        let override = UserDefaults.standard.integer(forKey: "FreePublishedLimit")
        return override > 0 ? override : defaultFreePublishedLimit
    }

    /// ¿Puede publicar una obra más? Republicar una ya publicada nunca cuenta.
    static func canPublish(isPro: Bool, publishedCount: Int, alreadyPublished: Bool, limit: Int = freePublishedLimit) -> Bool {
        isPro || alreadyPublished || publishedCount < limit
    }
}

enum PurchaseOutcome: Equatable {
    case purchased
    case cancelled
    case pending
    case failed(String)
}

@MainActor
@Observable
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    private(set) var isPro = false
    private(set) var isConfigured = false
    private(set) var offering: Offering?
    private(set) var isLoadingOfferings = false
    private(set) var managementURL: URL?
    var errorMessage: String?

    private let logger = Logger(subsystem: "app.framestudio.ios", category: "Subscriptions")
    private var listenTask: Task<Void, Never>?

    /// Clave pública del SDK. Vacía si no se configuró `REVENUECAT_API_KEY` (ver Config/Secrets.example.env).
    nonisolated static var apiKey: String {
        FrameStudioSecrets.revenueCatAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func configure() {
        guard !isConfigured else { return }
        let key = Self.apiKey
        guard !key.isEmpty else {
            // Sin clave la app funciona igual: todo es gratis hasta el límite y el paywall
            // muestra "no configurado" en DEBUG.
            logger.warning("RevenueCat not configured: REVENUECAT_API_KEY is empty")
            return
        }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: key)
        Purchases.shared.delegate = self
        isConfigured = true
        listenTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        guard isConfigured else { return }
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            logger.error("customerInfo failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadOfferings() async {
        guard isConfigured, !isLoadingOfferings else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.offering(identifier: ProPlan.offeringID) ?? offerings.current
        } catch {
            logger.error("offerings failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "No se pudieron cargar los planes. Revisa tu conexión."
        }
    }

    func purchase(_ package: Package) async -> PurchaseOutcome {
        guard isConfigured else { return .failed("Las compras no están configuradas.") }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)
            return isPro ? .purchased : .pending
        } catch let error as ErrorCode where error == .paymentPendingError {
            return .pending
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            return .cancelled
        } catch {
            errorMessage = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func restore() async -> Bool {
        guard isConfigured else {
            errorMessage = "Las compras no están configuradas."
            return false
        }
        do {
            apply(try await Purchases.shared.restorePurchases())
            if !isPro { errorMessage = "No encontramos compras anteriores con este Apple ID." }
            return isPro
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements[ProPlan.entitlementID]?.isActive == true
        managementURL = info.managementURL
    }
}

extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in self.apply(customerInfo) }
    }
}
