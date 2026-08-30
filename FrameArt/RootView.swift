import SwiftData
import SwiftUI

struct RootView: View {
    @State private var router = DeepLinkRouter.shared
    @State private var profile = ArtistProfile.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                if profile.hasStudioName || router.artistPieceID != nil {
                    ArtworkListView()
                } else {
                    StudioNameView()
                }
            }
            .tabItem {
                Label("Taller", systemImage: "photo.artframe")
            }
            .tag(DeepLinkRouter.Tab.taller)

            NavigationStack {
                MiEspacioView()
            }
            .tabItem {
                Label("Mi espacio", systemImage: "cube.transparent")
            }
            .tag(DeepLinkRouter.Tab.miEspacio)
        }
        .tint(FrameStudioBrand.hunter)
        .overlay {
            if router.isIngesting {
                ZStack {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                    ProgressView("Abriendo la obra…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .alert("No se pudo abrir", isPresented: Binding(
            get: { router.errorMessage != nil },
            set: { if !$0 { router.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(router.errorMessage ?? "")
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [ArtworkPiece.self, ReceivedPiece.self], inMemory: true)
}
