import Foundation
import Observation

@MainActor
@Observable
final class ArtistProfile {
    static let shared = ArtistProfile()
    static let nameKey = "artistDisplayName"
    static let slugKey = "artistSlug"

    var displayName: String
    var slug: String

    var hasStudioName: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private init() {
        displayName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        slug = UserDefaults.standard.string(forKey: Self.slugKey) ?? ""
    }

    func save(displayName rawName: String, slug rawSlug: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        var handle = Self.makeStudioSlug(from: rawSlug.isEmpty ? name : rawSlug)
        if handle.isEmpty {
            handle = Self.randomSlug()
        }
        displayName = name
        slug = handle
        UserDefaults.standard.set(name, forKey: Self.nameKey)
        UserDefaults.standard.set(handle, forKey: Self.slugKey)
    }

    /// Igual que RESERVED_STUDIOS en netlify/lib/store.ts: rutas del sitio que no pueden ser un estudio.
    nonisolated static let reservedStudios: Set<String> = [
        "api", "assets", "privacy", "terms", "support", "well-known", "index", "admin", "static"
    ]

    /// Slug compatible con el servidor (`^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$`): solo ASCII a-z/0-9
    /// y guiones internos. Letras no latinas se descartan (antes pasaban y el servidor rechazaba la publicación).
    nonisolated static func makeSlug(from raw: String, keepTrailingDash: Bool = false) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
        var out = ""
        var lastDash = false
        for scalar in folded.unicodeScalars {
            let v = scalar.value
            let isAlnum = (v >= 0x61 && v <= 0x7A) || (v >= 0x30 && v <= 0x39)
            if isAlnum {
                out.append(Character(scalar))
                lastDash = false
            } else if !out.isEmpty && !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        out = String(out.prefix(32))
        while !keepTrailingDash && out.hasSuffix("-") { out.removeLast() }
        return out
    }

    /// Slug de estudio válido: no vacío y no reservado (si lo es, se le añade "-estudio").
    nonisolated static func makeStudioSlug(from raw: String) -> String {
        let slug = makeSlug(from: raw)
        return reservedStudios.contains(slug) ? "\(slug)-estudio" : slug
    }

    nonisolated static func randomSlug() -> String {
        let chars = Array("abcdefghjkmnpqrstuvwxyz23456789")
        return String((0..<7).map { _ in chars.randomElement()! })
    }
}
