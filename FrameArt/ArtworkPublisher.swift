import Foundation
import UIKit

enum ArtworkPublisher {
    private static var publishEndpoint: URL {
        URL(string: "\(ClientViewer.origin)/api/publish")!
    }

    private static var unpublishEndpoint: URL {
        URL(string: "\(ClientViewer.origin)/api/unpublish")!
    }

    @MainActor
    static func publish(_ piece: ArtworkPiece) async throws -> URL {
        let profile = ArtistProfile.shared
        if profile.slug.isEmpty {
            profile.save(displayName: profile.displayName, slug: ArtistProfile.randomSlug())
        }
        let studio = profile.slug
        let artwork = piece.ensurePublicSlug()
        // Obtiene credenciales antes de exportar para fallar rápido (y reclamar el estudio).
        _ = try await authorization(for: studio)

        try ArtworkExporter.exportShareMeshes(for: piece)

        let title = piece.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let image = ArtworkFileStore.loadImage(for: piece) {
            let poster = image.normalizedUpright().resized(maxDimension: 2048)
            guard let data = poster.jpegData(compressionQuality: 0.9) else {
                throw PublishError.imageEncodingFailed
            }
            try await upload(
                studio: studio,
                artwork: artwork,
                kind: "poster",
                title: title,
                body: data,
                contentType: "image/jpeg"
            )
        }

        guard let usdzURL = ArtworkFileStore.usdzURL(for: piece),
              let glbURL = ArtworkFileStore.glbURL(for: piece) else {
            throw PublishError.missingFiles
        }
        let usdzData = try Data(contentsOf: usdzURL)
        let glbData = try Data(contentsOf: glbURL)
        try await upload(
            studio: studio,
            artwork: artwork,
            kind: "usdz",
            title: title,
            body: usdzData,
            contentType: "model/vnd.usdz+zip"
        )
        try await upload(
            studio: studio,
            artwork: artwork,
            kind: "glb",
            title: title,
            body: glbData,
            contentType: "model/gltf-binary"
        )

        let createdAt = ISO8601DateFormatter().string(from: piece.createdAt)
        let meta = try JSONSerialization.data(
            withJSONObject: ["title": title.isEmpty ? "Obra" : title, "createdAt": createdAt]
        )
        try await upload(
            studio: studio,
            artwork: artwork,
            kind: "meta",
            title: title,
            body: meta,
            contentType: "application/json"
        )

        return ClientViewer.shareURL(studio: studio, artwork: artwork)
    }

    static func unpublishBestEffort(studio: String, artwork: String) async {
        guard !studio.isEmpty, !artwork.isEmpty,
              let auth = try? await authorization(for: studio) else { return }
        var request = URLRequest(url: unpublishEndpoint)
        request.httpMethod = "POST"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "studio": studio,
            "artwork": artwork,
        ])
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Límites alineados con netlify/lib/limits.ts.
    static let maxBytes: [String: Int] = [
        "poster": 3 * 1024 * 1024,
        "usdz": 6 * 1024 * 1024,
        "glb": 6 * 1024 * 1024,
        "meta": 4 * 1024,
    ]

    /// Cabecera Authorization: token de App Attest; si no está disponible, clave legacy (si existe).
    static func authorization(for studio: String) async throws -> String {
        do {
            return "Bearer \(try await DeviceAuth.shared.bearer(for: studio))"
        } catch DeviceAuth.AuthError.studioTaken {
            throw PublishError.studioTaken
        } catch {
            let legacy = FrameStudioSecrets.publishKey
            guard !legacy.isEmpty else {
                throw (error as? DeviceAuth.AuthError) == .unsupported ? PublishError.deviceNotSupported : PublishError.missingKey
            }
            return "Bearer \(legacy)"
        }
    }

    private static func upload(
        studio: String,
        artwork: String,
        kind: String,
        title: String,
        body: Data,
        contentType: String,
        isRetry: Bool = false
    ) async throws {
        guard body.count <= maxBytes[kind, default: 0] else { throw PublishError.fileTooLarge }
        var components = URLComponents(url: publishEndpoint, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "studio", value: studio),
            URLQueryItem(name: "artwork", value: artwork),
            URLQueryItem(name: "kind", value: kind),
        ]
        if !title.isEmpty {
            items.append(URLQueryItem(name: "title", value: title))
        }
        components.queryItems = items
        guard let url = components.url else { throw PublishError.uploadFailed }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(try await authorization(for: studio), forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 120
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200...299:
            return
        case 401 where !isRetry:
            await DeviceAuth.shared.invalidate()
            try await upload(studio: studio, artwork: artwork, kind: kind, title: title,
                             body: body, contentType: contentType, isRetry: true)
        case 403, 409:
            throw PublishError.studioTaken
        case 413:
            throw PublishError.fileTooLarge
        case 429:
            throw PublishError.rateLimited
        default:
            throw PublishError.uploadFailed
        }
    }

    enum PublishError: LocalizedError {
        case missingKey
        case missingFiles
        case imageEncodingFailed
        case uploadFailed
        case fileTooLarge
        case rateLimited
        case studioTaken
        case deviceNotSupported

        var errorDescription: String? {
            switch self {
            case .missingKey:
                "Falta la clave de publicación."
            case .missingFiles:
                "No hay archivos AR para publicar."
            case .imageEncodingFailed:
                "No se pudo preparar la imagen."
            case .uploadFailed:
                "No se pudo publicar el enlace. Inténtalo de nuevo."
            case .fileTooLarge:
                "La obra es demasiado pesada para publicarla (máx. 6 MB por archivo)."
            case .rateLimited:
                "Has publicado muchas veces seguidas. Espera un rato e inténtalo de nuevo."
            case .studioTaken:
                "Este nombre de estudio pertenece a otro dispositivo. Cámbialo en Mi espacio."
            case .deviceNotSupported:
                "Este dispositivo no puede publicar (App Attest no disponible)."
            }
        }
    }
}
