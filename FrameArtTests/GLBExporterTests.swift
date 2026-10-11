import Foundation
import Testing
@testable import FrameArt

@Suite("GLBExporter")
struct GLBExporterTests {
    private func export(width: Double = 50, height: Double = 0) throws -> Data {
        let url = TempFile.url("glb")
        defer { try? FileManager.default.removeItem(at: url) }
        try GLBExporter.exportPainting(image: TestImage.make(width: 400, height: 300), widthCentimeters: width,
                                       heightCentimeters: height, title: "t", to: url)
        return try Data(contentsOf: url)
    }

    @Test func headerIsGLTF2WithCorrectLength() throws {
        let d = try export()
        #expect(d.prefix(4) == Data("glTF".utf8))
        #expect(d.le32(4) == 2)
        #expect(Int(d.le32(8)) == d.count)
    }

    @Test func chunksAreJSONThenBINAnd4ByteAligned() throws {
        let d = try export()
        let jsonLen = Int(d.le32(12))
        #expect(d.le32(16) == 0x4E4F_534A)
        #expect(jsonLen % 4 == 0)
        let bin = 20 + jsonLen
        #expect(d.le32(bin + 4) == 0x004E_4942)
        let binLen = Int(d.le32(bin))
        #expect(binLen % 4 == 0)
        #expect(bin + 8 + binLen == d.count)
    }

    @Test func jsonDeclaresAssetUnlitAndBuffers() throws {
        let d = try export()
        let jsonLen = Int(d.le32(12))
        let obj = try JSONSerialization.jsonObject(with: d.subdata(in: 20..<20 + jsonLen))
        let json = try #require(obj as? [String: Any])
        #expect((json["asset"] as? [String: Any])?["version"] as? String == "2.0")
        #expect((json["extensionsUsed"] as? [String])?.contains("KHR_materials_unlit") == true)
        let buffers = try #require(json["buffers"] as? [[String: Any]])
        let declared = try #require(buffers.first?["byteLength"] as? Int)
        let binLen = Int(d.le32(20 + jsonLen))
        #expect(declared <= binLen && binLen - declared < 4)
        #expect((json["meshes"] as? [Any])?.isEmpty == false)
        #expect((json["images"] as? [Any])?.isEmpty == false)
    }

    @Test func positionsMatchRequestedWidth() throws {
        let d = try export(width: 80, height: 60)
        let jsonLen = Int(d.le32(12))
        let json = try #require(try JSONSerialization.jsonObject(with: d.subdata(in: 20..<20 + jsonLen)) as? [String: Any])
        let accessors = try #require(json["accessors"] as? [[String: Any]])
        let withBounds = accessors.compactMap { a -> (Double, Double)? in
            guard let mx = a["max"] as? [Double], let mn = a["min"] as? [Double], mx.count == 3 else { return nil }
            return (mx[0] - mn[0], mx[1] - mn[1])
        }
        let (w, h) = try #require(withBounds.first)
        #expect(abs(w - 0.8) < 0.01, "ancho \(w)")
        #expect(abs(h - 0.6) < 0.01, "alto \(h)")
    }
}
