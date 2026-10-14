import Foundation
import SwiftData

/// Esquema versionado de SwiftData.
///
/// V1 = esquema publicado en 1.0.0-rc.1 (`ArtworkPiece`, `ReceivedPiece`).
/// Reglas para cambios futuros:
/// - Nunca edites un esquema ya publicado. Crea `FrameStudioSchemaV2` con copias congeladas de los modelos V1
///   dentro de `FrameStudioSchemaV1` y mueve los modelos vivos a V2.
/// - Propiedad nueva opcional o con valor por defecto → `MigrationStage.lightweight`.
/// - Renombrar → `@Attribute(originalName:)`. Cambios de semántica → `MigrationStage.custom`.
enum FrameStudioSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [ArtworkPiece.self, ReceivedPiece.self] }
}

enum FrameStudioMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [FrameStudioSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
