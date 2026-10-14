import Foundation

/// Conteo de vistas del enlace de una obra (solo el dueño, con sesión App Attest).
enum ViewCounter {
    static func count(studio: String, artwork: String) async -> Int? {
        guard !studio.isEmpty, !artwork.isEmpty,
              var components = URLComponents(string: ClientViewer.origin) else { return nil }
        components.path = "/api/views"
        components.queryItems = [URLQueryItem(name: "studio", value: studio), URLQueryItem(name: "artwork", value: artwork)]
        guard let url = components.url, let bearer = try? await DeviceAuth.shared.bearer(for: studio) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let count = json["count"] as? Int
        if let count { UserDefaults.standard.set(count, forKey: cacheKey(artwork)) }
        return count
    }

    /// Último conteo conocido (para la cuadrícula sin pedir red por cada obra).
    static func cached(artwork: String) -> Int? {
        UserDefaults.standard.object(forKey: cacheKey(artwork)) as? Int
    }

    private static func cacheKey(_ artwork: String) -> String { "viewCount.\(artwork)" }

    static func badge(_ count: Int?) -> String {
        guard let count, count > 0 else { return "Publicada" }
        return count == 1 ? "Publicada · 1 vista" : "Publicada · \(count) vistas"
    }

    static func label(_ count: Int) -> String {
        count == 1 ? "Vista 1 vez" : "Vista \(count) veces"
    }
}
