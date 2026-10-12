import CryptoKit
import DeviceCheck
import Foundation

/// Autenticación de publicación por dispositivo con App Attest.
///
/// Flujo: GET /api/auth/challenge → attest (primera vez) o assertion → token de sesión de 15 min ligado al estudio.
/// Si App Attest no está disponible (simulador) o el servidor aún no lo tiene configurado, `ArtworkPublisher`
/// usa la clave legacy mientras exista.
actor DeviceAuth {
    static let shared = DeviceAuth()

    private static let keyIdAccount = "appattest.keyId"
    private var cached: (token: String, studio: String, expires: Date)?

    enum AuthError: LocalizedError, Equatable {
        case unsupported
        case notConfigured
        case studioTaken
        case rejected(Int)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .unsupported: "Este dispositivo no admite App Attest."
            case .notConfigured: "El servidor aún no tiene App Attest configurado."
            case .studioTaken: "Ese nombre de estudio ya lo usa otro dispositivo. Elige otro en Mi espacio."
            case .rejected(let code): "El servidor rechazó la verificación del dispositivo (\(code))."
            case .badResponse: "Respuesta inesperada del servidor."
            }
        }
    }

    nonisolated var isSupported: Bool { DCAppAttestService.shared.isSupported }

    func invalidate() { cached = nil }

    /// Devuelve un token Bearer para publicar en `studio`.
    func bearer(for studio: String) async throws -> String {
        if let c = cached, c.studio == studio, c.expires > Date().addingTimeInterval(60) { return c.token }
        guard isSupported else { throw AuthError.unsupported }

        let token: String
        if let keyId = KeychainStore.get(Self.keyIdAccount) {
            do {
                token = try await assert(keyId: keyId, studio: studio)
            } catch AuthError.rejected(401) {
                // Clave desconocida en el servidor o inválida: regenerar y volver a atestiguar.
                KeychainStore.delete(Self.keyIdAccount)
                token = try await attest(studio: studio)
            } catch let error as DCError where error.code == .invalidKey {
                KeychainStore.delete(Self.keyIdAccount)
                token = try await attest(studio: studio)
            }
        } else {
            token = try await attest(studio: studio)
        }
        cached = (token, studio, Date().addingTimeInterval(14 * 60))
        return token
    }

    private func attest(studio: String) async throws -> String {
        let service = DCAppAttestService.shared
        let keyId = try await service.generateKey()
        let nonce = try await fetchChallenge()
        let attestation = try await service.attestKey(keyId, clientDataHash: Self.hash(nonce))
        let token = try await exchange(path: "/api/auth/attest", body: [
            "keyId": keyId, "attestation": attestation.base64EncodedString(), "nonce": nonce, "studio": studio,
        ])
        KeychainStore.set(keyId, for: Self.keyIdAccount)
        return token
    }

    private func assert(keyId: String, studio: String) async throws -> String {
        let nonce = try await fetchChallenge()
        let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: Self.hash(nonce))
        return try await exchange(path: "/api/auth/assert", body: [
            "keyId": keyId, "assertion": assertion.base64EncodedString(), "nonce": nonce, "studio": studio,
        ])
    }

    private static func hash(_ nonce: String) -> Data {
        Data(SHA256.hash(data: Data(nonce.utf8)))
    }

    private func fetchChallenge() async throws -> String {
        var request = URLRequest(url: URL(string: "\(ClientViewer.origin)/api/auth/challenge")!)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { throw AuthError.notConfigured }
        guard (200...299).contains(code),
              let nonce = try? JSONDecoder().decode([String: String].self, from: data)["nonce"] else {
            throw AuthError.badResponse
        }
        return nonce
    }

    private func exchange(path: String, body: [String: String]) async throws -> String {
        var request = URLRequest(url: URL(string: "\(ClientViewer.origin)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch code {
        case 200...299:
            guard let token = try? JSONDecoder().decode([String: String].self, from: data)["token"] else {
                throw AuthError.badResponse
            }
            return token
        case 404, 503: throw AuthError.notConfigured
        case 409: throw AuthError.studioTaken
        default: throw AuthError.rejected(code)
        }
    }
}
