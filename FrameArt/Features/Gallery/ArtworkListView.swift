import SwiftData
import SwiftUI

struct ArtworkListView: View {
    @State private var subscriptions = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var showSettings = false
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArtworkPiece.createdAt, order: .reverse) private var pieces: [ArtworkPiece]
    @State private var query = ""
    @State private var showAdd = false
    @State private var pendingDelete: ArtworkPiece?
    @State private var deleteError: String?
    @State private var profile = ArtistProfile.shared
    @State private var router = DeepLinkRouter.shared
    @State private var openedPiece: ArtworkPiece?
    @State private var firstSavedPiece: ArtworkPiece?
    @AppStorage("firstArtworkFollowUpDone") private var firstArtworkFollowUpDone = false

    private var filtered: [ArtworkPiece] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pieces }
        return pieces.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 280), spacing: 12)
    ]

    var body: some View {
        Group {
            if pieces.isEmpty {
                ContentUnavailableView {
                    Label("Sin obras", systemImage: "photo.artframe")
                } description: {
                    Text("Fotografía una pintura, elígela de la galería o importa un escaneo 3D.")
                } actions: {
                    Button("Añadir obra") {
                        showAdd = true
                    }
                    .primaryButtonStyle()
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filtered, id: \.id) { piece in
                            NavigationLink {
                                ArtworkDetailView(piece: piece)
                            } label: {
                                ArtworkGridItem(piece: piece)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Eliminar", systemImage: "trash", role: .destructive) {
                                    pendingDelete = piece
                                }
                            }
                            .accessibilityLabel(accessibilityLabel(for: piece))
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(profile.hasStudioName ? profile.displayName : "Obras")
        .searchable(text: $query, prompt: "Buscar obras")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Ajustes")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Añadir obra")
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { openedPiece != nil },
            set: { if !$0 { openedPiece = nil; router.consumeArtistPiece() } }
        )) {
            if let openedPiece {
                ArtworkDetailView(piece: openedPiece)
            }
        }
        .onChange(of: router.artistPieceID) { _, id in
            openArtistPiece(id: id)
        }
        .onAppear {
            openArtistPiece(id: router.artistPieceID)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(source: .settings, pain: OnboardingStore.shared.selectedPain) { showPaywall = false }
        }
        .navigationDestination(isPresented: Binding(
            get: { firstSavedPiece != nil },
            set: { if !$0 { firstSavedPiece = nil } }
        )) {
            if let firstSavedPiece {
                ArtworkDetailView(piece: firstSavedPiece, isFirstArtwork: true)
            }
        }
        .sheet(isPresented: $showAdd, onDismiss: {
            // Primera obra real guardada: se abre su ficha con la sugerencia de compartir y los avisos.
            guard !firstArtworkFollowUpDone, pieces.count == 1, let first = pieces.first else { return }
            firstArtworkFollowUpDone = true
            firstSavedPiece = first
        }) {
            NavigationStack {
                AddArtworkView()
            }
        }
        .alert("Borrar obra", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "¿Eliminar esta obra?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let piece = pendingDelete {
                    delete(piece)
                }
                pendingDelete = nil
            }
            Button("Cancelar", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("Se borran la foto y los archivos AR de “\(pendingDelete?.title ?? "esta obra")”.")
        }
    }

    private func openArtistPiece(id: UUID?) {
        guard let id else { return }
        openedPiece = pieces.first(where: { $0.id == id })
    }

    private func accessibilityLabel(for piece: ArtworkPiece) -> String {
        let name = piece.title.isEmpty ? "Sin título" : piece.title
        return "\(name), \(piece.kind.title), \(Int(piece.widthCentimeters)) centímetros"
    }

    private func delete(_ piece: ArtworkPiece) {
        let studio = ArtistProfile.shared.slug
        let artwork = piece.publicSlug
        modelContext.delete(piece)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            ErrorReporter.record(error, context: "delete.save")
            deleteError = "No se pudo borrar la obra. Inténtalo de nuevo."
            return
        }
        ArtworkFileStore.deleteFiles(forID: piece.id)
        guard !studio.isEmpty, !artwork.isEmpty else { return }
        Task {
            if await !ArtworkPublisher.unpublish(studio: studio, artwork: artwork) {
                PendingUnpublish.add(studio: studio, artwork: artwork)
                deleteError = "La obra se borró del taller, pero su enlace sigue público porque no hubo conexión. Lo retiraremos en cuanto se pueda."
            }
        }
    }
}

struct ArtworkGridItem: View {
    let piece: ArtworkPiece
    @State private var viewCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(piece.title.isEmpty ? "Sin título" : piece.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(piece.kind.title) · \(MeasureFormat.size(width: piece.widthCentimeters, height: piece.heightCentimeters))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !piece.publicSlug.isEmpty {
                PublishedBadge(count: viewCount)
            }
        }
        .task(id: piece.publicSlug) {
            guard !piece.publicSlug.isEmpty else { return }
            viewCount = ViewCounter.cached(artwork: piece.publicSlug)
            if let fresh = await ViewCounter.count(studio: ArtistProfile.shared.slug, artwork: piece.publicSlug) {
                viewCount = fresh
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ArtworkFileStore.loadImage(for: piece) {
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            Image(systemName: piece.kind.systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.fill.tertiary)
        }
    }
}
