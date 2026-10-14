import Testing
@testable import FrameArt

struct ProPlanTests {
    @Test func freeUserCanPublishUnderLimit() {
        #expect(ProPlan.canPublish(isPro: false, publishedCount: 2, alreadyPublished: false, limit: 3))
    }

    @Test func freeUserBlockedAtLimit() {
        #expect(!ProPlan.canPublish(isPro: false, publishedCount: 3, alreadyPublished: false, limit: 3))
    }

    @Test func republishingNeverCounts() {
        #expect(ProPlan.canPublish(isPro: false, publishedCount: 10, alreadyPublished: true, limit: 3))
    }

    @Test func proIsUnlimited() {
        #expect(ProPlan.canPublish(isPro: true, publishedCount: 500, alreadyPublished: false, limit: 3))
    }

    @Test func identifiers() {
        #expect(ProPlan.entitlementID == "pro")
        #expect(ProPlan.offeringID == "default")
        #expect(ProPlan.monthlyProductID.hasPrefix("app.framestudio.ios.pro."))
    }
}
