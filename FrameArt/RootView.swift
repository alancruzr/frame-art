import SwiftData
import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            ArtworkListView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: ArtworkPiece.self, inMemory: true)
}
