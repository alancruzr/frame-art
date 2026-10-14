import Foundation
import OSLog

/// Eventos de producto. Sin datos personales: nunca títulos, nombres, slugs ni URLs.
enum AnalyticsEvent: Equatable {
    case onboardingStep(index: Int, name: String)
    case onboardingGoalSelected(String)
    case onboardingPainSelected(String)
    case onboardingDemoImage(source: String)
    case onboardingCompleted
    case demoGuideStep(step: String, mode: String)
    case demoGuideSkipped(step: String)
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
    case arSnapshotTaken
    case linkCopied
    case qrShown
    case publishLimitReached(limit: Int)
    case arOpened(source: String)
    case pushPermissionPrompted
    case pushPermissionGranted
    case clientLinkOpenedNotificationTapped

    var name: String {
        switch self {
        case .onboardingStep: return "onboarding_step"
        case .onboardingGoalSelected: return "onboarding_goal_selected"
        case .onboardingPainSelected: return "onboarding_pain_selected"
        case .onboardingDemoImage: return "onboarding_demo_image"
        case .onboardingCompleted: return "onboarding_completed"
        case .demoGuideStep: return "demo_guide_step"
        case .demoGuideSkipped: return "demo_guide_skipped"
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
        case .arSnapshotTaken: return "ar_snapshot_taken"
        case .linkCopied: return "link_copied"
        case .qrShown: return "qr_shown"
        case .publishLimitReached: return "publish_limit_reached"
        case .arOpened: return "ar_opened"
        case .pushPermissionPrompted: return "push_permission_prompted"
        case .pushPermissionGranted: return "push_permission_granted"
        case .clientLinkOpenedNotificationTapped: return "client_link_opened_notification_tapped"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .onboardingStep(let index, let name): return ["step_index": index, "step_name": name]
        case .onboardingGoalSelected(let goal): return ["goal": goal]
        case .onboardingPainSelected(let pain): return ["pain": pain]
        case .onboardingDemoImage(let source): return ["source": source]
        case .onboardingCompleted: return [:]
        case .demoGuideStep(let step, let mode): return ["step": step, "mode": mode]
        case .demoGuideSkipped(let step): return ["step": step]
        case .permissionResult(let kind, let granted): return ["kind": kind, "granted": granted ? 1 : 0]
        case .paywallViewed(let source), .paywallDismissed(let source): return ["source": source]
        case .paywallPlanSelected(let id), .paywallPurchaseStarted(let id), .paywallPurchaseCompleted(let id),
             .paywallPurchaseCancelled(let id), .paywallPurchaseFailed(let id):
            return ["product_id": id]
        case .paywallRestore(let success): return ["success": success ? 1 : 0]
        case .artworkAdded(let kind): return ["kind": kind]
        case .artworkPublished(let isFirst): return ["is_first": isFirst ? 1 : 0]
        case .artworkShared, .arSnapshotTaken, .linkCopied, .qrShown: return [:]
        case .publishLimitReached(let limit): return ["limit": limit]
        case .arOpened(let source): return ["source": source]
        case .pushPermissionPrompted, .pushPermissionGranted, .clientLinkOpenedNotificationTapped: return [:]
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
