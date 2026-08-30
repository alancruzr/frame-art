import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    enum Tab: Hashable {
        case taller
        case miEspacio
    }

    var selectedTab: Tab = .taller
    var artistPieceID: UUID?
    var receivedARID: UUID?
    var isIngesting = false
    var errorMessage: String?
    /// Share links skip artist onboarding for this session so Mi espacio can open AR.
    var deferOnboarding = false

    private init() {}

    func open(url: URL, context: ModelContext) async {
        guard let parsed = ClientViewer.parseArtworkLink(url) else { return }
        deferOnboarding = true
        let studio = parsed.studio
        let artwork = parsed.artwork

        if ArtistProfile.shared.slug == studio {
            let slug = artwork
            let owned = FetchDescriptor<ArtworkPiece>(
                predicate: #Predicate { $0.publicSlug == slug }
            )
            if let piece = try? context.fetch(owned).first {
                artistPieceID = piece.id
                selectedTab = .taller
                return
            }
        }

        selectedTab = .miEspacio
        isIngesting = true
        errorMessage = nil
        defer { isIngesting = false }
        do {
            let received = try await ingest(studio: studio, artwork: artwork, context: context)
            receivedARID = received.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func consumeArtistPiece() {
        artistPieceID = nil
    }

    func consumeReceivedAR() {
        receivedARID = nil
    }

    private func ingest(studio: String, artwork: String, context: ModelContext) async throws -> ReceivedPiece {
        let studioKey = studio
        let artworkKey = artwork
        let existingFetch = FetchDescriptor<ReceivedPiece>(
            predicate: #Predicate { $0.studioSlug == studioKey && $0.artworkSlug == artworkKey }
        )
        let existing = try? context.fetch(existingFetch).first
        let piece = existing ?? ReceivedPiece(
            studioSlug: studio,
            studioName: Self.displayName(from: studio),
            artworkSlug: artwork,
            title: artwork
        )
        if existing == nil {
            context.insert(piece)
        }

        let base = ClientViewer.artworkURL(studio: studio, artwork: artwork)
        if let title = await Self.fetchTitle(from: base), !title.isEmpty {
            piece.title = title
        }
        if piece.studioName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            piece.studioName = Self.displayName(from: studio)
        }

        let posterData = try await Self.download(base.appending(path: "poster.jpg"))
        if let posterData {
            piece.imageFileName = try ArtworkFileStore.saveData(posterData, for: piece.id, fileName: "image.jpg")
        }

        guard let usdzData = try await Self.download(base.appending(path: "model.usdz")) else {
            throw IngestError.missingArtwork
        }
        piece.usdzFileName = try ArtworkFileStore.saveData(usdzData, for: piece.id, fileName: "model.usdz")

        if let glbData = try await Self.download(base.appending(path: "model.glb")) {
            piece.glbFileName = try ArtworkFileStore.saveData(glbData, for: piece.id, fileName: "model.glb")
        }

        try context.save()
        return piece
    }

    private static func displayName(from slug: String) -> String {
        slug.split(separator: "-").map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined(separator: " ")
    }

    private static func fetchTitle(from page: URL) async -> String? {
        guard let data = try? await download(page),
              let html = String(data: data, encoding: .utf8) else { return nil }
        if let match = html.firstMatch(of: /id="title">([^<]+)</) {
            let title = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
        }
        if let match = html.firstMatch(of: /<title>([^<]+)<\/title>/) {
            var title = String(match.1)
            if let range = title.range(of: " — Frame Studio") {
                title.removeSubrange(range)
            }
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
        }
        return nil
    }

    private static func download(_ url: URL) async throws -> Data? {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode), !data.isEmpty else { return nil }
        return data
    }

    enum IngestError: LocalizedError {
        case missingArtwork

        var errorDescription: String? {
            switch self {
            case .missingArtwork:
                "No se encontró esta obra."
            }
        }
    }
}
