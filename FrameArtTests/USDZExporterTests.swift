import Foundation
import Testing
@testable import FrameArt

@Suite("USDZExporter")
struct USDZExporterTests {
    private func exportPainting(width: Double = 60, height: Double = 45) throws -> Data {
        let url = TempFile.url("usdz")
        defer { try? FileManager.default.removeItem(at: url) }
        try USDZExporter.exportPainting(image: TestImage.make(), widthCentimeters: width,
                                        heightCentimeters: height, title: "Prueba \"ñ\"", to: url)
        return try Data(contentsOf: url)
    }

    @Test func exportProducesZipWithUSDLayerFirst() throws {
        let d = try exportPainting()
        #expect(d.prefix(4) == ZipReader.localSig)
        let entries = ZipReader.entries(d)
        #expect(!entries.isEmpty)
        let first = try #require(entries.first)
        #expect([".usda", ".usdc", ".usd"].contains { first.name.hasSuffix($0) },
                "La capa USD raíz debe ser la primera entrada: \(first.name)")
    }

    @Test func exportEntriesAreStoredAnd64ByteAligned() throws {
        let entries = ZipReader.entries(try exportPainting())
        for e in entries {
            #expect(e.method == 0, "USDZ exige entradas sin comprimir: \(e.name)")
            #expect(e.dataOffset % 64 == 0, "Datos no alineados a 64 bytes: \(e.name) @\(e.dataOffset)")
        }
    }

    @Test func exportContainsTexture() throws {
        let entries = ZipReader.entries(try exportPainting())
        #expect(entries.contains { $0.name.lowercased().hasSuffix(".jpg") || $0.name.lowercased().hasSuffix(".png") })
    }

    // MARK: Escritor manual (fallback)

    @Test func manualWriterAlignsAndChecksums() throws {
        let url = TempFile.url("usdz")
        defer { try? FileManager.default.removeItem(at: url) }
        let usda = Data("#usda 1.0\n".utf8)
        let tex = Data((0..<1000).map { UInt8($0 % 251) })
        try USDZExporter.writeUSDZ(to: url, files: [("Artwork.usda", usda), ("texture.jpg", tex)])
        let entries = ZipReader.entries(try Data(contentsOf: url))
        #expect(entries.map(\.name) == ["Artwork.usda", "texture.jpg"])
        for e in entries {
            #expect(e.method == 0)
            #expect(e.dataOffset % 64 == 0)
            #expect(CRC32.hash(e.data) == e.crc, "CRC32 incorrecto en \(e.name)")
        }
        #expect(entries[1].data == tex)
    }

    @Test func usdaDeclaresMetersYUpAndWallAnchoring() {
        let usda = USDZExporter.makeUSDA(displayName: "Atardecer", widthMeters: 0.8, heightMeters: 0.6,
                                         thicknessMeters: 0.008, textureFileName: "texture.jpg")
        #expect(usda.hasPrefix("#usda 1.0"))
        #expect(usda.contains("metersPerUnit = 1"))
        #expect(usda.contains("upAxis = \"Y\""))
        #expect(usda.contains("planeAnchoring:alignment = \"vertical\""))
        #expect(usda.contains("texture.jpg"))
    }

    @Test func crc32KnownVector() {
        // CRC-32/ISO-HDLC de "123456789" = 0xCBF43926
        #expect(CRC32.hash(Data("123456789".utf8)) == 0xCBF4_3926)
    }
}
