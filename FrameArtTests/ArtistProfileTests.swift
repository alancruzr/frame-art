import Foundation
import Testing
@testable import FrameArt

struct ArtistProfileSlugTests {
    private let serverRegex = /^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$/

    @Test func foldsAccentsAndSpaces() {
        #expect(ArtistProfile.makeSlug(from: "Taller Peña Ñandú") == "taller-pena-nandu")
    }

    @Test func dropsNonLatinLetters() {
        let slug = ArtistProfile.makeSlug(from: "東京 Studio 🎨")
        #expect(slug == "studio")
        #expect(ArtistProfile.makeSlug(from: "東京").isEmpty)
    }

    @Test func neverEndsWithDashAfterTruncation() {
        let slug = ArtistProfile.makeSlug(from: String(repeating: "a", count: 31) + " bbbb")
        #expect(!slug.hasSuffix("-"))
        #expect(slug.wholeMatch(of: serverRegex) != nil)
    }

    @Test func reservedStudiosAreAvoided() {
        #expect(ArtistProfile.makeStudioSlug(from: "API") == "api-estudio")
        #expect(ArtistProfile.makeStudioSlug(from: "Assets") == "assets-estudio")
        #expect(ArtistProfile.makeStudioSlug(from: "Luna") == "luna")
    }

    @Test func randomSlugMatchesServer() {
        #expect(ArtistProfile.randomSlug().wholeMatch(of: serverRegex) != nil)
    }
}

struct ArtistProfileEditingTests {
    @Test func editingKeepsTrailingDash() {
        #expect(ArtistProfile.makeSlug(from: "taller-", keepTrailingDash: true) == "taller-")
        #expect(ArtistProfile.makeSlug(from: "taller-") == "taller")
    }
}
