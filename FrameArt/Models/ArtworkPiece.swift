import Foundation
import SwiftData

@Model
final class ArtworkPiece {
    var id: UUID
    var title: String
    var createdAt: Date
    var widthCentimeters: Double
    var kindRaw: String
    var imageFileName: String?
    var usdzFileName: String?
    var glbFileName: String?

    var kind: ArtworkKind {
        get { ArtworkKind(rawValue: kindRaw) ?? .paintingPhoto }
        set { kindRaw = newValue.rawValue }
    }

    var widthMeters: Float {
        Float(widthCentimeters / 100.0)
    }

    init(
        id: UUID = UUID(),
        title: String = "Sin título",
        createdAt: Date = .now,
        widthCentimeters: Double = 60,
        kind: ArtworkKind,
        imageFileName: String? = nil,
        usdzFileName: String? = nil,
        glbFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.widthCentimeters = widthCentimeters
        self.kindRaw = kind.rawValue
        self.imageFileName = imageFileName
        self.usdzFileName = usdzFileName
        self.glbFileName = glbFileName
    }
}
