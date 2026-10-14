import Testing
@testable import FrameArt

struct PushTests {
    @Test func artworkURLFromPayload() {
        let url = PushNotifications.artworkURL(from: ["studio": "taller-luna", "artwork": "mar-1234"])
        #expect(url?.absoluteString == "https://frame-studio.netlify.app/taller-luna/mar-1234/")
        #expect(PushNotifications.artworkURL(from: ["studio": "x"]) == nil)
    }

    @Test func viewLabel() {
        #expect(ViewCounter.label(1) == "Vista 1 vez")
        #expect(ViewCounter.label(7) == "Vista 7 veces")
    }
}
