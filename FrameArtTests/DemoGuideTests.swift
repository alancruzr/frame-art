import Testing
@testable import FrameArt

struct DemoGuideTests {
    @Test func arHappyPath() {
        var g = DemoGuide(mode: .ar)
        #expect(g.step == .choosePainting)
        let r1 = g.handle(.paintingChosen); #expect(r1); #expect(g.step == .scanWall)
        let r2 = g.handle(.wallDetected); #expect(r2); #expect(g.step == .tapToPlace)
        let r3 = g.handle(.placed); #expect(r3); #expect(g.step == .adjust)
        let r4 = g.handle(.adjusted); #expect(r4); #expect(g.step == .share)
        let r5 = g.handle(.shareTapped); #expect(r5); #expect(g.isFinished)
    }

    @Test func simulatedSkipsScan() {
        var g = DemoGuide(mode: .simulated)
        g.handle(.paintingChosen)
        #expect(g.step == .tapToPlace)
        let r6 = g.handle(.wallDetected); #expect(!r6)
        let r7 = g.handle(.wallLost); #expect(!r7)
        #expect(g.step == .tapToPlace)
    }

    @Test func losingWallGoesBackToScan() {
        var g = DemoGuide(mode: .ar)
        g.handle(.paintingChosen); g.handle(.wallDetected)
        let r8 = g.handle(.wallLost); #expect(r8)
        #expect(g.step == .scanWall)
    }

    @Test func outOfOrderEventsIgnored() {
        var g = DemoGuide(mode: .ar)
        let r9 = g.handle(.placed); #expect(!r9)
        let r10 = g.handle(.shareTapped); #expect(!r10)
        g.handle(.paintingChosen)
        let r11 = g.handle(.adjusted); #expect(!r11)
        #expect(g.step == .scanWall)
    }

    @Test func skipAdvancesOneStep() {
        var g = DemoGuide(mode: .ar)
        g.handle(.paintingChosen)
        g.handle(.skip); #expect(g.step == .tapToPlace)
        g.handle(.skip); #expect(g.step == .adjust)
        g.handle(.skip); #expect(g.step == .share)
        g.handle(.skip); #expect(g.isFinished)
        let r12 = g.handle(.skip); #expect(!r12)
    }

    @Test func fallbackFromScanJumpsToTap() {
        var g = DemoGuide(mode: .ar)
        g.handle(.paintingChosen)
        g.fallBackToSimulated()
        #expect(g.mode == .simulated)
        #expect(g.step == .tapToPlace)
    }

    @Test func clampScale() {
        #expect(ARPlacementState.clampScale(5) == 2)
        #expect(ARPlacementState.clampScale(0.1) == 0.5)
    }
}
