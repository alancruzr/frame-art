import Foundation
import SwiftData

@Model
final class ArtworkPiece {
    var id: UUID
    var title: String
    var createdAt: Date
    var widthCentimeters: Double
    var heightCentimeters: Double = 0
    var kindRaw: String
    var imageFileName: String?
    var usdzFileName: String?
    var glbFileName: String?
    /// Public path segment `{slug}-{uuid8}` used at frame-studio.netlify.app/{studio}/{artwork}/
    var publicSlug: String = ""

    var kind: ArtworkKind {
        get { ArtworkKind(rawValue: kindRaw) ?? .paintingPhoto }
        set { kindRaw = newValue.rawValue }
    }

    var widthMeters: Float {
        Float(widthCentimeters / 100.0)
    }

    var heightMeters: Float {
        Float(resolvedHeightCentimeters / 100.0)
    }

    /// Stored height, or width if height was never set.
    var resolvedHeightCentimeters: Double {
        heightCentimeters >= 1 ? heightCentimeters : widthCentimeters
    }

    func resolvedHeightCentimeters(aspect: Double) -> Double {
        if heightCentimeters >= 1 { return heightCentimeters }
        guard aspect > 0 else { return widthCentimeters }
        return (widthCentimeters * aspect).rounded()
    }

    @discardableResult
    func ensurePublicSlug() -> String {
        if !publicSlug.isEmpty { return publicSlug }
        let base = ArtistProfile.makeSlug(from: title)
        let suffix = String(id.uuidString.prefix(8)).lowercased()
        let stem = base.isEmpty ? "obra" : base
        var slug = "\(stem)-\(suffix)"
        if slug.count > 64 {
            slug = String(slug.prefix(64))
        }
        publicSlug = slug
        return publicSlug
    }

    init(
        id: UUID = UUID(),
        title: String = "Sin título",
        createdAt: Date = .now,
        widthCentimeters: Double = 60,
        heightCentimeters: Double = 0,
        kind: ArtworkKind,
        imageFileName: String? = nil,
        usdzFileName: String? = nil,
        glbFileName: String? = nil,
        publicSlug: String = ""
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.widthCentimeters = widthCentimeters
        self.heightCentimeters = heightCentimeters
        self.kindRaw = kind.rawValue
        self.imageFileName = imageFileName
        self.usdzFileName = usdzFileName
        self.glbFileName = glbFileName
        self.publicSlug = publicSlug
    }
}
