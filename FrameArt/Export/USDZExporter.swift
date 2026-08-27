import Foundation
import UIKit

/// Builds a Quick Look–ready USDZ (textured vertical plane).
///
/// RealityKit `Entity.write(to:)` (iOS 18+) writes `.reality`, not USDZ.
/// This exporter follows the Pixar USDZ spec: uncompressed ZIP, 64-byte
/// aligned file payloads, USDA first, JPEG texture second.
enum USDZExporter {
    static func exportPainting(
        image: UIImage,
        widthCentimeters: Double,
        title: String,
        to destination: URL
    ) throws {
        let prepared = image.normalizedUpright().resized(maxDimension: 2048)
        let widthM = widthCentimeters / 100.0
        let heightM = widthM * (prepared.size.height / max(prepared.size.width, 1))

        guard let jpeg = prepared.jpegData(compressionQuality: 0.9) else {
            throw ExportError.imageEncodingFailed
        }

        let usda = makeUSDA(
            displayName: title,
            widthMeters: widthM,
            heightMeters: heightM,
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

    private static func makeUSDA(
        displayName: String,
        widthMeters: Double,
        heightMeters: Double,
        textureFileName: String
    ) -> String {
        let nw = String(format: "%.6f", -widthMeters / 2)
        let nh = String(format: "%.6f", -heightMeters / 2)
        let pw = String(format: "%.6f", widthMeters / 2)
        let ph = String(format: "%.6f", heightMeters / 2)
        let escaped = displayName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return """
        #usda 1.0
        (
            defaultPrim = "Artwork"
            metersPerUnit = 1
            upAxis = "Y"
            doc = "Frame Art — plano texturizado para AR Quick Look"
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
                        float inputs:metallic = 0
                        float inputs:roughness = 0.75
                        int inputs:useSpecularWorkflow = 0
                        token outputs:surface
                    }

                    def Shader "DiffuseTexture"
                    {
                        uniform token info:id = "UsdUVTexture"
                        asset inputs:file = @\(textureFileName)@
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
            }

            def Mesh "Painting"
            {
                uniform bool doubleSided = 1
                float3[] extent = [(\(nw), \(nh), -0.001), (\(pw), \(ph), 0.001)]
                int[] faceVertexCounts = [4]
                int[] faceVertexIndices = [0, 1, 2, 3]
                rel material:binding = </Artwork/Looks/PaintingMaterial>
                normal3f[] normals = [(0, 0, 1), (0, 0, 1), (0, 0, 1), (0, 0, 1)] (
                    interpolation = "vertex"
                )
                point3f[] points = [(\(nw), \(nh), 0), (\(pw), \(nh), 0), (\(pw), \(ph), 0), (\(nw), \(ph), 0)]
                texCoord2f[] primvars:st = [(0, 0), (1, 0), (1, 1), (0, 1)] (
                    interpolation = "vertex"
                )
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
