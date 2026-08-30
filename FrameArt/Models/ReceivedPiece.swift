import Foundation
import SwiftData

@Model
final class ReceivedPiece {
    var id: UUID
    var studioSlug: String
    var studioName: String
    var artworkSlug: String
    var title: String
    var imageFileName: String?
    var usdzFileName: String?
    var glbFileName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        studioSlug: String,
        studioName: String,
        artworkSlug: String,
        title: String,
        imageFileName: String? = nil,
        usdzFileName: String? = nil,
        glbFileName: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.studioSlug = studioSlug
        self.studioName = studioName
        self.artworkSlug = artworkSlug
        self.title = title
        self.imageFileName = imageFileName
        self.usdzFileName = usdzFileName
        self.glbFileName = glbFileName
        self.createdAt = createdAt
    }

    /// Transient piece for ArtworkARContainer / ArtworkFileStore. Not inserted into SwiftData.
    func asArtworkPiece() -> ArtworkPiece {
        ArtworkPiece(
            id: id,
            title: title,
            createdAt: createdAt,
            kind: .scan3D,
            imageFileName: imageFileName,
            usdzFileName: usdzFileName,
            glbFileName: glbFileName,
            publicSlug: artworkSlug
        )
    }
}
