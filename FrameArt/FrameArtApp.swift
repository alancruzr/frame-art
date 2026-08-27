import SwiftData
import SwiftUI

@main
struct FrameArtApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: ArtworkPiece.self)
    }
}
