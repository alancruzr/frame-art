import Foundation
import OSLog

/// Eventos de producto. Sin datos personales: nunca títulos, nombres, slugs ni URLs.
enum AnalyticsEvent: Equatable {
    case onboardingStep(index: Int, name: String)
    case onboardingGoalSelected(String)
    case onboardingPainSelected(String)
    case onboardingCommitment(days: Int, reminders: Bool)
    case onboardingDemoImage(source: String)
    case onboardingCompleted
    case permissionResult(kind: String, granted: Bool)
    case paywallViewed(source: String)
    case paywallPlanSelected(productID: String)
    case paywallPurchaseStarted(productID: String)
    case paywallPurchaseCompleted(productID: String)
    case paywallPurchaseCancelled(productID: String)
    case paywallPurchaseFailed(productID: String)
    case paywallRestore(success: Bool)
    case paywallDismissed(source: String)
    case artworkAdded(kind: String)
    case artworkPublished(isFirst: Bool)
    case artworkShared
    case publishLimitReached(limit: Int)
    case arOpened(source: String)

    var name: String {
        switch self {
        case .onboardingStep: return "onboarding_step"
        case .onboardingGoalSelected: return "onboarding_goal_selected"
        case .onboardingPainSelected: return "onboarding_pain_selected"
        case .onboardingCommitment: return "onboarding_commitment"
        case .onboardingDemoImage: return "onboarding_demo_image"
        case .onboardingCompleted: return "onboarding_completed"
        case .permissionResult: return "permission_result"
        case .paywallViewed: return "paywall_viewed"
        case .paywallPlanSelected: return "paywall_plan_selected"
        case .paywallPurchaseStarted: return "paywall_purchase_started"
        case .paywallPurchaseCompleted: return "paywall_purchase_completed"
        case .paywallPurchaseCancelled: return "paywall_purchase_cancelled"
        case .paywallPurchaseFailed: return "paywall_purchase_failed"
        case .paywallRestore: return "paywall_restore"
        case .paywallDismissed: return "paywall_dismissed"
        case .artworkAdded: return "artwork_added"
        case .artworkPublished: return "artwork_published"
        case .artworkShared: return "artwork_shared"
        case .publishLimitReached: return "publish_limit_reached"
        case .arOpened: return "ar_opened"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .onboardingStep(let index, let name): return ["step_index": index, "step_name": name]
        case .onboardingGoalSelected(let goal): return ["goal": goal]
        case .onboardingPainSelected(let pain): return ["pain": pain]
        case .onboardingCommitment(let days, let reminders): return ["days_count": days, "reminders": reminders ? 1 : 0]
        case .onboardingDemoImage(let source): return ["source": source]
        case .onboardingCompleted: return [:]
        case .permissionResult(let kind, let granted): return ["kind": kind, "granted": granted ? 1 : 0]
        case .paywallViewed(let source), .paywallDismissed(let source): return ["source": source]
        case .paywallPlanSelected(let id), .paywallPurchaseStarted(let id), .paywallPurchaseCompleted(let id),
             .paywallPurchaseCancelled(let id), .paywallPurchaseFailed(let id):
            return ["product_id": id]
        case .paywallRestore(let success): return ["success": success ? 1 : 0]
        case .artworkAdded(let kind): return ["kind": kind]
        case .artworkPublished(let isFirst): return ["is_first": isFirst ? 1 : 0]
        case .artworkShared: return [:]
        case .publishLimitReached(let limit): return ["limit": limit]
        case .arOpened(let source): return ["source": source]
        }
    }
}

/// Fachada única de analítica. Escribe en el log unificado y reenvía a los destinos
/// registrados (Firebase cuando está configurado).
@MainActor
enum Analytics {
    private static let logger = Logger(subsystem: "app.framestudio.ios", category: "Analytics")
    static var sinks: [(AnalyticsEvent) -> Void] = []

    static func log(_ event: AnalyticsEvent) {
        logger.info("event \(event.name, privacy: .public)")
        for sink in sinks { sink(event) }
    }
}
