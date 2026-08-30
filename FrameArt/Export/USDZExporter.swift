import Foundation
import SceneKit
import UIKit

/// Builds a Quick Look–ready USDZ: a thin textured slab (not a zero-thickness plane).
///
/// Primary path: SceneKit `SCNScene.write(to:)` so Apple’s exporter emits a valid USDZ.
/// Fallback: handmade USDA ZIP with an 8 mm box (painting on +Z) if SceneKit write fails.
enum USDZExporter {
    static let thicknessMeters: Double = 0.008

    static func exportPainting(
        image: UIImage,
        widthCentimeters: Double,
        heightCentimeters: Double,
        title: String,
        to destination: URL
    ) throws {
        let prepared = image.normalizedUpright().resized(maxDimension: 2048)
        let widthM = widthCentimeters / 100.0
        let heightCm: Double = {
            if heightCentimeters >= 1 { return heightCentimeters }
            let aspect = Double(prepared.size.height / max(prepared.size.width, 1))
            guard aspect > 0 else { return widthCentimeters }
            return (widthCentimeters * aspect).rounded()
        }()
        let heightM = max(heightCm, 2) / 100.0

        guard let jpeg = prepared.jpegData(compressionQuality: 0.9) else {
            throw ExportError.imageEncodingFailed
        }

        if writeSceneKitUSDZ(
            jpeg: jpeg,
            widthMeters: widthM,
            heightMeters: heightM,
            title: title,
            to: destination
        ) {
            return
        }

        let usda = makeUSDA(
            displayName: title,
            widthMeters: widthM,
            heightMeters: heightM,
            thicknessMeters: thicknessMeters,
            textureFileName: "texture.jpg"
        )
        guard let usdaData = usda.data(using: .utf8) else {
            throw ExportError.usdaEncodingFailed
        }

        try writeUSDZ(
            to: destination,
            files: [
                ("Artwork.usda", usdaData),
                ("texture.jpg", jpeg),
            ]
        )
    }

    /// Apple-valid USDZ via SceneKit. Painting on the front (+Z) of an 8 mm box,
    /// unlit (constant + emission) so Quick Look is not black without lights.
    @discardableResult
    private static func writeSceneKitUSDZ(
        jpeg: Data,
        widthMeters: Double,
        heightMeters: Double,
        title: String,
        to destination: URL
    ) -> Bool {
        let tmp: URL
        do {
            tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("frame-usdz-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        } catch {
            return false
        }
        defer { try? FileManager.default.removeItem(at: tmp) }

        let texURL = tmp.appendingPathComponent("texture.jpg")
        do { try jpeg.write(to: texURL, options: .atomic) } catch { return false }

        let paint = SCNMaterial()
        paint.lightingModel = .constant
        paint.diffuse.contents = texURL
        paint.emission.contents = texURL
        paint.diffuse.wrapS = .clamp
        paint.diffuse.wrapT = .clamp
        paint.emission.wrapS = .clamp
        paint.emission.wrapT = .clamp
        paint.isDoubleSided = true

        let edge = SCNMaterial()
        edge.lightingModel = .constant
        edge.diffuse.contents = UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1)
        edge.emission.contents = UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1)
        edge.isDoubleSided = true

        // SCNBox materials: front, right, back, left, top, bottom. Front is +Z.
        let box = SCNBox(
            width: CGFloat(widthMeters),
            height: CGFloat(heightMeters),
            length: CGFloat(thicknessMeters),
            chamferRadius: 0
        )
        box.materials = [paint, edge, paint, edge, edge, edge]

        let node = SCNNode(geometry: box)
        node.name = "Painting"
        let scene = SCNScene()
        scene.rootNode.name = title.isEmpty ? "Artwork" : title
        scene.rootNode.addChildNode(node)

        let staging = tmp.appendingPathComponent("model.usdz")
        let ok = scene.write(to: staging, options: nil, delegate: nil, progressHandler: nil)
        guard ok else { return false }

        guard let data = try? Data(contentsOf: staging),
              data.count > 256,
              data.starts(with: [0x50, 0x4B]) else {
            return false
        }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func makeUSDA(
        displayName: String,
        widthMeters: Double,
        heightMeters: Double,
        thicknessMeters: Double,
        textureFileName: String
    ) -> String {
        let hw = widthMeters / 2
        let hh = heightMeters / 2
        let ht = thicknessMeters / 2
        let f = { (v: Double) in String(format: "%.6f", v) }
        let escaped = displayName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        // Front (+Z) — painting. USD st origin is lower-left.
        let frontPoints = """
                        (\(f(-hw)), \(f(-hh)), \(f(ht))), (\(f(hw)), \(f(-hh)), \(f(ht))), (\(f(hw)), \(f(hh)), \(f(ht))), (\(f(-hw)), \(f(hh)), \(f(ht)))
        """
        // Back, right, left, top, bottom — dark slab so the piece cannot vanish edge-on.
        let slabPoints = """
                        (\(f(hw)), \(f(-hh)), \(f(-ht))), (\(f(-hw)), \(f(-hh)), \(f(-ht))), (\(f(-hw)), \(f(hh)), \(f(-ht))), (\(f(hw)), \(f(hh)), \(f(-ht))), (\(f(hw)), \(f(-hh)), \(f(ht))), (\(f(hw)), \(f(-hh)), \(f(-ht))), (\(f(hw)), \(f(hh)), \(f(-ht))), (\(f(hw)), \(f(hh)), \(f(ht))), (\(f(-hw)), \(f(-hh)), \(f(-ht))), (\(f(-hw)), \(f(-hh)), \(f(ht))), (\(f(-hw)), \(f(hh)), \(f(ht))), (\(f(-hw)), \(f(hh)), \(f(-ht))), (\(f(-hw)), \(f(hh)), \(f(ht))), (\(f(hw)), \(f(hh)), \(f(ht))), (\(f(hw)), \(f(hh)), \(f(-ht))), (\(f(-hw)), \(f(hh)), \(f(-ht))), (\(f(-hw)), \(f(-hh)), \(f(-ht))), (\(f(hw)), \(f(-hh)), \(f(-ht))), (\(f(hw)), \(f(-hh)), \(f(ht))), (\(f(-hw)), \(f(-hh)), \(f(ht)))
        """

        return """
        #usda 1.0
        (
            defaultPrim = "Artwork"
            metersPerUnit = 1
            upAxis = "Y"
            doc = "Frame Art — losa texturizada 8 mm para AR Quick Look"
        )

        def Xform "Artwork" (
            assetInfo = {
                string name = "\(escaped)"
            }
            kind = "component"
            prepend apiSchemas = ["Preliminary_AnchoringAPI"]
        )
        {
            uniform token preliminary:anchoring:type = "plane"
            uniform token preliminary:planeAnchoring:alignment = "vertical"

            def Scope "Looks"
            {
                def Material "PaintingMaterial"
                {
                    token outputs:surface.connect = </Artwork/Looks/PaintingMaterial/PreviewSurface.outputs:surface>

                    def Shader "PreviewSurface"
                    {
                        uniform token info:id = "UsdPreviewSurface"
                        color3f inputs:diffuseColor.connect = </Artwork/Looks/PaintingMaterial/DiffuseTexture.outputs:rgb>
                        color3f inputs:emissiveColor.connect = </Artwork/Looks/PaintingMaterial/DiffuseTexture.outputs:rgb>
                        float inputs:metallic = 0
                        float inputs:roughness = 1
                        int inputs:useSpecularWorkflow = 0
                        token outputs:surface
                    }

                    def Shader "DiffuseTexture"
                    {
                        uniform token info:id = "UsdUVTexture"
                        asset inputs:file = @\(textureFileName)@
                        token inputs:sourceColorSpace = "sRGB"
                        float2 inputs:st.connect = </Artwork/Looks/PaintingMaterial/PrimvarST.outputs:result>
                        token inputs:wrapS = "clamp"
                        token inputs:wrapT = "clamp"
                        float3 outputs:rgb
                    }

                    def Shader "PrimvarST"
                    {
                        uniform token info:id = "UsdPrimvarReader_float2"
                        token inputs:varname = "st"
                        float2 outputs:result
                    }
                }

                def Material "EdgeMaterial"
                {
                    token outputs:surface.connect = </Artwork/Looks/EdgeMaterial/PreviewSurface.outputs:surface>

                    def Shader "PreviewSurface"
                    {
                        uniform token info:id = "UsdPreviewSurface"
                        color3f inputs:diffuseColor = (0.12, 0.10, 0.08)
                        color3f inputs:emissiveColor = (0.08, 0.07, 0.05)
                        float inputs:metallic = 0
                        float inputs:roughness = 1
                        token outputs:surface
                    }
                }
            }

            def Mesh "Painting"
            {
                uniform bool doubleSided = 1
                float3[] extent = [(\(f(-hw)), \(f(-hh)), \(f(-ht))), (\(f(hw)), \(f(hh)), \(f(ht)))]
                int[] faceVertexCounts = [3, 3]
                int[] faceVertexIndices = [0, 1, 2, 0, 2, 3]
                rel material:binding = </Artwork/Looks/PaintingMaterial>
                normal3f[] normals = [(0, 0, 1), (0, 0, 1), (0, 0, 1), (0, 0, 1)] (
                    interpolation = "vertex"
                )
                point3f[] points = [\(frontPoints)]
                texCoord2f[] primvars:st = [(0, 0), (1, 0), (1, 1), (0, 1)] (
                    interpolation = "vertex"
                )
                uniform token subdivisionScheme = "none"
            }

            def Mesh "Slab"
            {
                float3[] extent = [(\(f(-hw)), \(f(-hh)), \(f(-ht))), (\(f(hw)), \(f(hh)), \(f(ht)))]
                int[] faceVertexCounts = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
                int[] faceVertexIndices = [0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7, 8, 9, 10, 8, 10, 11, 12, 13, 14, 12, 14, 15, 16, 17, 18, 16, 18, 19]
                rel material:binding = </Artwork/Looks/EdgeMaterial>
                normal3f[] normals = [(0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1), (1, 0, 0), (1, 0, 0), (1, 0, 0), (1, 0, 0), (-1, 0, 0), (-1, 0, 0), (-1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, 1, 0), (0, 1, 0), (0, 1, 0), (0, -1, 0), (0, -1, 0), (0, -1, 0), (0, -1, 0)] (
                    interpolation = "vertex"
                )
                point3f[] points = [\(slabPoints)]
                uniform token subdivisionScheme = "none"
            }
        }

        """
    }

    /// Uncompressed ZIP with 64-byte aligned local file payloads (USDZ spec).
    private static func writeUSDZ(to url: URL, files: [(String, Data)]) throws {
        var entries: [(name: String, crc: UInt32, size: UInt32, offset: UInt32)] = []
        var archive = Data()

        for (name, payload) in files {
            let nameData = Data(name.utf8)
            let crc = CRC32.hash(payload)
            let size = UInt32(payload.count)
            let headerBase = 30 + nameData.count
            let extraLen = extraLength(currentOffset: archive.count, headerBase: headerBase)

            var local = Data()
            local.appendUInt32(0x0403_4b50)
            local.appendUInt16(20)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt32(crc)
            local.appendUInt32(size)
            local.appendUInt32(size)
            local.appendUInt16(UInt16(nameData.count))
            local.appendUInt16(UInt16(extraLen))
            local.append(nameData)
            if extraLen > 0 {
                local.append(Data(count: extraLen))
            }

            let offset = UInt32(archive.count)
            archive.append(local)
            archive.append(payload)
            entries.append((name, crc, size, offset))
        }

        let cdStart = UInt32(archive.count)
        for entry in entries {
            let nameData = Data(entry.name.utf8)
            var cd = Data()
            cd.appendUInt32(0x0201_4b50)
            cd.appendUInt16(20)
            cd.appendUInt16(20)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt32(entry.crc)
            cd.appendUInt32(entry.size)
            cd.appendUInt32(entry.size)
            cd.appendUInt16(UInt16(nameData.count))
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt32(0)
            cd.appendUInt32(entry.offset)
            cd.append(nameData)
            archive.append(cd)
        }

        let cdSize = UInt32(archive.count) - cdStart
        var eocd = Data()
        eocd.appendUInt32(0x0605_4b50)
        eocd.appendUInt16(0)
        eocd.appendUInt16(0)
        eocd.appendUInt16(UInt16(entries.count))
        eocd.appendUInt16(UInt16(entries.count))
        eocd.appendUInt32(cdSize)
        eocd.appendUInt32(cdStart)
        eocd.appendUInt16(0)
        archive.append(eocd)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try archive.write(to: url, options: .atomic)
    }

    private static func extraLength(currentOffset: Int, headerBase: Int) -> Int {
        let misalignment = (currentOffset + headerBase) % 64
        if misalignment == 0 { return 0 }
        var extra = 64 - misalignment
        if extra > 0 && extra < 4 {
            extra += 64
        }
        return extra
    }

    enum ExportError: LocalizedError {
        case imageEncodingFailed
        case usdaEncodingFailed

        var errorDescription: String? {
            switch self {
            case .imageEncodingFailed: "No se pudo codificar la textura JPEG."
            case .usdaEncodingFailed: "No se pudo escribir el USDA."
            }
        }
    }
}

enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if c & 1 != 0 {
                    c = 0xEDB8_8320 ^ (c >> 1)
                } else {
                    c >>= 1
                }
            }
            return c
        }
    }()

    static func hash(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
