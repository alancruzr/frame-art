import Foundation
import SwiftData
import Testing
@testable import FrameArt

@Suite("Persistence")
@MainActor
struct PersistenceTests {
    @Test func inMemoryContainerOpensWithMigrationPlan() throws {
        guard case .ready(let container) = PersistenceController.make(inMemory: true) else {
            Issue.record("No se abrió el contenedor"); return
        }
        let ctx = container.mainContext
        ctx.insert(ArtworkPiece(title: "Prueba", kind: .paintingPhoto))
        try ctx.save()
        #expect(try ctx.fetchCount(FetchDescriptor<ArtworkPiece>()) == 1)
    }

    @Test func defaultStoreURLIsTheLegacyDefault() {
        #expect(PersistenceController.defaultStoreURL.lastPathComponent == "default.store")
    }

    @Test func onDiskStoreSurvivesReopen() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let schema = PersistenceController.schema
        do {
            let c = try ModelContainer(for: schema, migrationPlan: FrameStudioMigrationPlan.self,
                                       configurations: ModelConfiguration(schema: schema, url: url))
            c.mainContext.insert(ArtworkPiece(title: "Persistida", kind: .paintingPhoto))
            try c.mainContext.save()
        }
        let reopened = try ModelContainer(for: schema, migrationPlan: FrameStudioMigrationPlan.self,
                                          configurations: ModelConfiguration(schema: schema, url: url))
        let items = try reopened.mainContext.fetch(FetchDescriptor<ArtworkPiece>())
        #expect(items.map(\.title) == ["Persistida"])
    }

    /// Simula el store de 1.0.0-rc.1, creado sin VersionedSchema, y lo abre con el plan de migración.
    @Test func legacyUnversionedStoreOpensWithPlan() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let legacy = try ModelContainer(for: ArtworkPiece.self, ReceivedPiece.self,
                                            configurations: ModelConfiguration(url: url))
            legacy.mainContext.insert(ArtworkPiece(title: "Legacy", kind: .paintingPhoto))
            try legacy.mainContext.save()
        }
        let schema = PersistenceController.schema
        let c = try ModelContainer(for: schema, migrationPlan: FrameStudioMigrationPlan.self,
                                   configurations: ModelConfiguration(schema: schema, url: url))
        #expect(try c.mainContext.fetch(FetchDescriptor<ArtworkPiece>()).map(\.title) == ["Legacy"])
    }
}
