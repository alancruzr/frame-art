import Foundation
import RealityKit
import UIKit

enum PaintingEntityFactory {
    /// Textured vertical plane in the entity XY plane (normal +Z), real-world width.
    /// Place it with `AnchorEntity(.plane(.vertical, classification: .wall, ...))`.
    @MainActor
    static func makePaintingEntity(
        image: UIImage,
        widthCentimeters: Double
    ) async throws -> ModelEntity {
        let widthMeters = Float(widthCentimeters / 100.0)
        let aspect = Float(image.size.height / max(image.size.width, 1))
        let heightMeters = widthMeters * aspect

        let mesh = MeshResource.generatePlane(width: widthMeters, height: heightMeters)

        guard let cgImage = image.normalizedUpright().cgImage else {
            throw FactoryError.missingCGImage
        }

        let texture = try await TextureResource(
            image: cgImage,
            options: TextureResource.CreateOptions(semantic: .color)
        )

        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "Painting"
        entity.generateCollisionShapes(recursive: true)
        entity.components.set(InputTargetComponent())
        return entity
    }

    @MainActor
    static func makeScanEntity(usdzURL: URL) async throws -> Entity {
        let entity = try await Entity(contentsOf: usdzURL)
        entity.generateCollisionShapes(recursive: true)
        return entity
    }

    /// RealityKit on iOS 18+ writes `.reality` files, not USDZ.
    /// API: `Entity.write(to:)` — https://developer.apple.com/documentation/realitykit/entity/write(to:)
    /// Requires a real device for AR preview; file write itself is available in the simulator.
    @MainActor
    static func writeRealityFile(_ entity: Entity, to url: URL) async throws {
        try await entity.write(to: url)
    }

    enum FactoryError: LocalizedError {
        case missingCGImage

        var errorDescription: String? {
            "No se pudo leer la imagen para crear el plano 3D."
        }
    }
}
