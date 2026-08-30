import SwiftData
import SwiftUI

struct MiEspacioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReceivedPiece.createdAt, order: .reverse) private var pieces: [ReceivedPiece]
    @State private var router = DeepLinkRouter.shared
    @State private var pendingDelete: ReceivedPiece?
    @State private var arPiece: ReceivedPiece?

    private var sections: [(name: String, slug: String, items: [ReceivedPiece])] {
        let grouped = Dictionary(grouping: pieces) { $0.studioSlug }
        return grouped.keys.sorted { a, b in
            let na = grouped[a]?.first?.studioName ?? a
            let nb = grouped[b]?.first?.studioName ?? b
            return na.localizedCaseInsensitiveCompare(nb) == .orderedAscending
        }.map { slug in
            let items = (grouped[slug] ?? []).sorted { $0.createdAt > $1.createdAt }
            let raw = items.first?.studioName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (raw.isEmpty ? slug : raw, slug, items)
        }
    }

    var body: some View {
        Group {
            if pieces.isEmpty {
                ContentUnavailableView {
                    Label("Mi espacio", systemImage: "cube.transparent")
                } description: {
                    Text("Las obras que te compartan para colgar aparecen aquí.")
                }
            } else {
                List {
                    ForEach(sections, id: \.slug) { section in
                        Section(section.name) {
                            ForEach(section.items, id: \.id) { piece in
                                Button {
                                    arPiece = piece
                                } label: {
                                    ReceivedPieceRow(piece: piece)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Eliminar", systemImage: "trash", role: .destructive) {
                                        pendingDelete = piece
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Eliminar", systemImage: "trash", role: .destructive) {
                                        pendingDelete = piece
                                    }
                                }
                                .accessibilityLabel(accessibilityLabel(for: piece))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Mi espacio")
        .fullScreenCover(isPresented: Binding(
            get: { arPiece != nil },
            set: { if !$0 { arPiece = nil; router.consumeReceivedAR() } }
        )) {
            if let arPiece {
                ArtworkARContainer(piece: arPiece.asArtworkPiece())
            }
        }
        .onChange(of: router.receivedARID) { _, id in
            presentAR(id: id)
        }
        .onAppear {
            presentAR(id: router.receivedARID)
        }
        .confirmationDialog(
            "¿Quitar esta obra de Mi espacio?",
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
            Text("Se borra de este iPhone. No se quita el enlace del artista.")
        }
    }

    private func presentAR(id: UUID?) {
        guard let id else { return }
        if let piece = pieces.first(where: { $0.id == id }) {
            arPiece = piece
        }
    }

    private func accessibilityLabel(for piece: ReceivedPiece) -> String {
        let name = piece.title.isEmpty ? "Sin título" : piece.title
        return "\(name), \(piece.studioName). Ver en mi espacio"
    }

    private func delete(_ piece: ReceivedPiece) {
        ArtworkFileStore.deleteFiles(forID: piece.id)
        modelContext.delete(piece)
    }
}

private struct ReceivedPieceRow: View {
    let piece: ReceivedPiece

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(piece.title.isEmpty ? "Sin título" : piece.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("Ver en mi espacio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ArtworkFileStore.loadImage(for: piece.asArtworkPiece()) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "cube.transparent")
                .foregroundStyle(FrameStudioBrand.gold)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.fill.tertiary)
        }
    }
}
