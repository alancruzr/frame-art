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
        var handle = Self.makeSlug(from: rawSlug.isEmpty ? name : rawSlug)
        if handle.isEmpty {
            handle = Self.randomSlug()
        }
        displayName = name
        slug = handle
        UserDefaults.standard.set(name, forKey: Self.nameKey)
        UserDefaults.standard.set(handle, forKey: Self.slugKey)
    }

    static func makeSlug(from raw: String) -> String {
        let folded = raw.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        var out = ""
        var lastDash = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                out.append(Character(scalar))
                lastDash = false
            } else if !out.isEmpty && !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        if out.hasSuffix("-") {
            out.removeLast()
        }
        return String(out.prefix(32))
    }

    static func randomSlug() -> String {
        let chars = Array("abcdefghjkmnpqrstuvwxyz23456789")
        return String((0..<7).map { _ in chars.randomElement()! })
    }
}
