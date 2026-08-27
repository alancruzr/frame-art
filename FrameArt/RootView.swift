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
    }
}

#Preview {
    RootView()
        .modelContainer(for: ArtworkPiece.self, inMemory: true)
}
