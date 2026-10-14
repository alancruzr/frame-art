import Testing
import UIKit
@testable import FrameArt

@MainActor
struct CornerCropTests {
    private func sampleImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
            UIColor.red.setFill(); ctx.fill(CGRect(x: 50, y: 25, width: 100, height: 50))
        }
    }

    @Test func fullQuadKeepsAspect() throws {
        let out = try #require(PaintingCanvasCropper.perspectiveCrop(sampleImage(), quad: .full))
        #expect(abs(out.size.width / out.size.height - 2) < 0.1)
    }

    @Test func innerQuadCropsRegion() throws {
        let quad = CornerQuad(topLeft: CGPoint(x: 0.25, y: 0.25), topRight: CGPoint(x: 0.75, y: 0.25),
                              bottomRight: CGPoint(x: 0.75, y: 0.75), bottomLeft: CGPoint(x: 0.25, y: 0.75))
        let out = try #require(PaintingCanvasCropper.perspectiveCrop(sampleImage(), quad: quad))
        #expect(out.size.width < 210 && out.size.width > 0)
    }

    @Test func subscriptClampsToUnitSquare() {
        var q = CornerQuad.inset
        q[0] = CGPoint(x: -1, y: 2)
        #expect(q.topLeft == CGPoint(x: 0, y: 1))
    }
}
