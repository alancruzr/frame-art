import SwiftData
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Obras", systemImage: "photo.on.rectangle.angled") {
                NavigationStack {
                    ArtworkListView()
                }
            }
            Tab("Nueva", systemImage: "plus") {
                NavigationStack {
                    AddArtworkView()
                }
            }
        }
        // iOS 26: system tab bar collapses on scroll. Do not paint a custom tab background.
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    RootView()
        .modelContainer(for: ArtworkPiece.self, inMemory: true)
}
