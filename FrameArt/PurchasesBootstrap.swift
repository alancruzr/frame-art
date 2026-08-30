import Foundation
import RevenueCat

enum PurchasesBootstrap {
    static func start() {
        let key = FrameStudioSecrets.revenueCatAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
    }
}
