import SwiftData
import SwiftUI

struct ArtworkListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArtworkPiece.createdAt, order: .reverse) private var pieces: [ArtworkPiece]

    var body: some View {
        Group {
            if pieces.isEmpty {
                ContentUnavailableView(
                    "Sin obras",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Añade una foto de una pintura o un escaneo 3D en la pestaña Nueva.")
                )
            } else {
                List {
                    ForEach(pieces, id: \.id) { piece in
                        NavigationLink {
                            ArtworkDetailView(piece: piece)
                        } label: {
                            ArtworkRowView(piece: piece)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Obras")
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let piece = pieces[index]
            ArtworkFileStore.deleteFiles(for: piece)
            modelContext.delete(piece)
        }
    }
}

struct ArtworkRowView: View {
    let piece: ArtworkPiece

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(piece.title.isEmpty ? "Sin título" : piece.title)
                Text("\(piece.kind.title) · \(Int(piece.widthCentimeters)) cm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ArtworkFileStore.loadImage(for: piece) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: piece.kind.systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.fill.tertiary)
        }
    }
}
