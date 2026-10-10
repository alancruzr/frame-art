import Foundation
import OSLog
import SwiftData

/// Abre el contenedor de SwiftData sin `fatalError`.
/// Usa la configuración por defecto (`default.store` en Application Support) para conservar los datos existentes.
enum PersistenceController {
    enum State {
        case ready(ModelContainer)
        case failed(String)
    }

    private static let log = Logger(subsystem: "com.alancruzr.frameart", category: "persistence")

    static var schema: Schema { Schema(versionedSchema: FrameStudioSchemaV1.self) }

    static func make(inMemory: Bool = false) -> State {
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: FrameStudioMigrationPlan.self,
                configurations: config
            )
            return .ready(container)
        } catch {
            log.error("ModelContainer failed: \(String(describing: error), privacy: .public)")
            return .failed(String(describing: error))
        }
    }

    /// URL del store por defecto (la misma que usaba `ModelContainer(for:)`).
    static var defaultStoreURL: URL {
        ModelConfiguration(schema: schema).url
    }

    /// Último recurso, con confirmación del usuario: mueve el store a una copia de seguridad y crea uno vacío.
    /// No toca los archivos de las obras (ArtworkFileStore).
    static func backupAndReset() -> State {
        let fm = FileManager.default
        let url = defaultStoreURL
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: url.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = url.deletingLastPathComponent()
                .appendingPathComponent("backup-\(stamp)-" + src.lastPathComponent)
            do { try fm.moveItem(at: src, to: dst) } catch {
                log.error("Backup failed for \(src.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        return make()
    }
}
