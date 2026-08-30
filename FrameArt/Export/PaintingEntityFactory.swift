import Foundation
import RealityKit
import UIKit

enum PaintingEntityFactory {
    /// Textured vertical plane in the entity XY plane (normal +Z), real-world width.
    @MainActor
    static func makePaintingEntity(
        image: UIImage,
        widthCentimeters: Double,
        heightCentimeters: Double,
        opacity: Float = 1
    ) async throws -> ModelEntity {
        let widthMeters = Float(widthCentimeters / 100.0)
        let heightMeters = Float(max(heightCentimeters, 1) / 100.0)

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
        applyOpacity(&material, opacity)

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "Painting"
        entity.generateCollisionShapes(recursive: true)
        entity.components.set(InputTargetComponent())
        return entity
    }

    @MainActor
    static func setOpacity(_ entity: ModelEntity, _ opacity: Float) {
        guard var model = entity.model else { return }
        var next: [RealityKit.Material] = []
        for material in model.materials {
            if var unlit = material as? UnlitMaterial {
                applyOpacity(&unlit, opacity)
                next.append(unlit)
            } else {
                next.append(material)
            }
        }
        model.materials = next
        entity.model = model
    }

    private static func applyOpacity(_ material: inout UnlitMaterial, _ opacity: Float) {
        if opacity >= 0.99 {
            material.blending = .opaque
        } else {
            material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        }
    }

    @MainActor
    static func makeScanEntity(usdzURL: URL) async throws -> Entity {
        let entity = try await Entity(contentsOf: usdzURL)
        entity.generateCollisionShapes(recursive: true)
        return entity
    }

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
