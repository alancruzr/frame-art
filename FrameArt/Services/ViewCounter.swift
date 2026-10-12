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
        return json["count"] as? Int
    }

    static func label(_ count: Int) -> String {
        count == 1 ? "Vista 1 vez" : "Vista \(count) veces"
    }
}
