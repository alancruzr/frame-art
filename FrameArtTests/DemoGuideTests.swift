import Testing
@testable import FrameArt

private func apply(_ g: inout DemoGuide, _ e: DemoGuideEvent) -> Bool { g.handle(e) }

struct DemoGuideTests {
    @Test func arHappyPathReachesAha() {
        var g = DemoGuide(mode: .ar)
        #expect(g.step == .choosePainting)
        #expect(apply(&g, .paintingChosen)); #expect(g.step == .scanWall)
        #expect(apply(&g, .wallDetected)); #expect(g.step == .tapToPlace)
        #expect(apply(&g, .placed)); #expect(g.step == .pin)
        #expect(apply(&g, .pinned)); #expect(g.step == .explore)
        #expect(apply(&g, .ahaReached)); #expect(g.step == .value)
        #expect(apply(&g, .continueTapped)); #expect(g.isFinished)
    }

    @Test func simulatedSkipsScan() {
        var g = DemoGuide(mode: .simulated)
        g.handle(.paintingChosen)
        #expect(g.step == .tapToPlace)
        #expect(!apply(&g, .wallDetected))
        #expect(!apply(&g, .wallLost))
        #expect(g.step == .tapToPlace)
    }

    @Test func losingWallGoesBackToScan() {
        var g = DemoGuide(mode: .ar)
        g.handle(.paintingChosen); g.handle(.wallDetected)
        #expect(apply(&g, .wallLost))
        #expect(g.step == .scanWall)
    }

    @Test func unpinAndMoveGoBack() {
        var g = DemoGuide(mode: .ar)
        g.handle(.paintingChosen); g.handle(.wallDetected); g.handle(.placed); g.handle(.pinned)
        #expect(apply(&g, .unpinned)); #expect(g.step == .pin)
        #expect(apply(&g, .moved)); #expect(g.step == .scanWall)
        var s = DemoGuide(mode: .simulated)
        s.handle(.paintingChosen); s.handle(.placed); s.handle(.pinned)
        #expect(apply(&s, .moved)); #expect(s.step == .tapToPlace)
    }

    @Test func ahaOnlyCountsWhilePinned() {
        var g = DemoGuide(mode: .ar)
        g.handle(.paintingChosen); g.handle(.wallDetected); g.handle(.placed)
        #expect(!apply(&g, .ahaReached))
        #expect(g.step == .pin)
    }

    @Test func outOfOrderEventsIgnored() {
        var g = DemoGuide(mode: .ar)
        #expect(!apply(&g, .placed))
        #expect(!apply(&g, .continueTapped))
        g.handle(.paintingChosen)
        #expect(!apply(&g, .pinned))
        #expect(g.step == .scanWall)
    }

    @Test func skipAdvancesOneStep() {
        var g = DemoGuide(mode: .ar)
        g.handle(.paintingChosen)
        g.handle(.skip); #expect(g.step == .tapToPlace)
        g.handle(.skip); #expect(g.step == .pin)
        g.handle(.skip); #expect(g.step == .explore)
        g.handle(.skip); #expect(g.step == .value)
        g.handle(.skip); #expect(g.isFinished)
        #expect(!apply(&g, .skip))
    }

    @Test func fallbackFromScanJumpsToTap() {
        var g = DemoGuide(mode: .ar)
        g.handle(.paintingChosen)
        g.fallBackToSimulated()
        #expect(g.mode == .simulated)
        #expect(g.step == .tapToPlace)
    }

    @Test func timings() {
        #expect(DemoGuide.ahaSeconds == 3)
        #expect(DemoGuide.wallTimeoutSeconds == 20)
    }
}
