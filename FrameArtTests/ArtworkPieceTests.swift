import Foundation
import Testing
@testable import FrameArt

@Suite("ArtworkPiece")
struct ArtworkPieceTests {
    @Test func publicSlugIsStableAndBounded() {
        let p = ArtworkPiece(title: String(repeating: "Atardecer en la playa ", count: 10), kind: .paintingPhoto)
        let s = p.ensurePublicSlug()
        #expect(s.count <= 64)
        #expect(p.ensurePublicSlug() == s)
        #expect(s.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil)
    }

    @Test func heightFallsBackToWidthOrAspect() {
        let p = ArtworkPiece(widthCentimeters: 60, heightCentimeters: 0, kind: .paintingPhoto)
        #expect(p.resolvedHeightCentimeters == 60)
        #expect(p.resolvedHeightCentimeters(aspect: 0.75) == 45)
    }
}
