import Foundation
import UIKit

/// Minimal glTF 2.0 / GLB writer for a textured 8 mm slab (not a zero-thickness plane).
/// Scene Viewer, WebXR and `<model-viewer>` consume this on Android and the web.
enum GLBExporter {
    static let thicknessMeters: Float = 0.008

    static func exportPainting(
        image: UIImage,
        widthCentimeters: Double,
        heightCentimeters: Double,
        title: String,
        to destination: URL
    ) throws {
        let prepared = image.normalizedUpright().resized(maxDimension: 2048)
        let widthM = Float(widthCentimeters / 100.0)
        let heightCm: Double = {
            if heightCentimeters >= 1 { return heightCentimeters }
            let aspect = Double(prepared.size.height / max(prepared.size.width, 1))
            guard aspect > 0 else { return widthCentimeters }
            return (widthCentimeters * aspect).rounded()
        }()
        let heightM = Float(max(heightCm, 2) / 100.0)

        guard let jpeg = prepared.jpegData(compressionQuality: 0.9) else {
            throw ExportError.imageEncodingFailed
        }

        let glb = try buildGLB(
            jpeg: jpeg,
            halfWidth: widthM / 2,
            halfHeight: heightM / 2,
            halfThick: thicknessMeters / 2,
            title: title
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try glb.write(to: destination, options: .atomic)
    }

    private static func buildGLB(
        jpeg: Data,
        halfWidth: Float,
        halfHeight: Float,
        halfThick: Float,
        title: String
    ) throws -> Data {
        var bin = Data()

        func appendFloats(_ values: [Float]) {
            for value in values {
                var bits = value.bitPattern.littleEndian
                Swift.withUnsafeBytes(of: &bits) { bin.append(contentsOf: $0) }
            }
        }

        let hw = halfWidth
        let hh = halfHeight
        let ht = halfThick

        // 6 faces × 4 verts (front, right, back, left, top, bottom). Y-up, painting on ±Z.
        let positions: [Float] = [
            -hw, -hh,  ht,   hw, -hh,  ht,   hw,  hh,  ht,  -hw,  hh,  ht,
             hw, -hh,  ht,   hw, -hh, -ht,   hw,  hh, -ht,   hw,  hh,  ht,
             hw, -hh, -ht,  -hw, -hh, -ht,  -hw,  hh, -ht,   hw,  hh, -ht,
            -hw, -hh, -ht,  -hw, -hh,  ht,  -hw,  hh,  ht,  -hw,  hh, -ht,
            -hw,  hh,  ht,   hw,  hh,  ht,   hw,  hh, -ht,  -hw,  hh, -ht,
            -hw, -hh, -ht,   hw, -hh, -ht,   hw, -hh,  ht,  -hw, -hh,  ht,
        ]
        appendFloats(positions)

        let normals: [Float] = [
            0, 0, 1,  0, 0, 1,  0, 0, 1,  0, 0, 1,
            1, 0, 0,  1, 0, 0,  1, 0, 0,  1, 0, 0,
            0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1,
            -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0,
            0, 1, 0,  0, 1, 0,  0, 1, 0,  0, 1, 0,
            0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0,
        ]
        appendFloats(normals)

        // glTF UV origin is top-left. Front/back get the painting; edges get a dark corner.
        var uvs: [Float] = []
        let faceUV: [[Float]] = [
            [0, 1, 1, 1, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [1, 1, 0, 1, 0, 0, 1, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
        ]
        for uv in faceUV { uvs.append(contentsOf: uv) }
        appendFloats(uvs)

        var indices: [UInt16] = []
        for face in 0..<6 {
            let b = UInt16(face * 4)
            indices.append(contentsOf: [b, b + 1, b + 2, b, b + 2, b + 3])
        }
        for i in indices.indices {
            var little = indices[i].littleEndian
            Swift.withUnsafeBytes(of: &little) { bin.append(contentsOf: $0) }
        }

        while bin.count % 4 != 0 {
            bin.append(0)
        }
        let imageOffset = bin.count
        bin.append(jpeg)
        while bin.count % 4 != 0 {
            bin.append(0)
        }

        let posLen = 24 * 3 * 4
        let nrmLen = 24 * 3 * 4
        let uvLen = 24 * 2 * 4
        let idxLen = 36 * 2

        let json: [String: Any] = [
            "asset": [
                "version": "2.0",
                "generator": "Frame Art",
            ],
            "extensionsUsed": ["KHR_materials_unlit"],
            "scene": 0,
            "scenes": [["nodes": [0], "name": title]],
            "nodes": [["mesh": 0, "name": "Artwork"]],
            "meshes": [[
                "name": "Painting",
                "primitives": [[
                    "attributes": [
                        "POSITION": 0,
                        "NORMAL": 1,
                        "TEXCOORD_0": 2,
                    ],
                    "indices": 3,
                    "material": 0,
                ]],
            ]],
            "materials": [[
                "name": "Painting",
                "doubleSided": true,
                "pbrMetallicRoughness": [
                    "baseColorTexture": ["index": 0],
                    "metallicFactor": 0,
                    "roughnessFactor": 1,
                ],
                "extensions": ["KHR_materials_unlit": [String: Any]()],
            ]],
            "textures": [["source": 0, "sampler": 0]],
            "images": [["mimeType": "image/jpeg", "bufferView": 4]],
            "samplers": [[
                "magFilter": 9729,
                "minFilter": 9729,
                "wrapS": 33071,
                "wrapT": 33071,
            ]],
            "buffers": [["byteLength": bin.count]],
            "bufferViews": [
                ["buffer": 0, "byteOffset": 0, "byteLength": posLen, "target": 34962],
                ["buffer": 0, "byteOffset": posLen, "byteLength": nrmLen, "target": 34962],
                ["buffer": 0, "byteOffset": posLen + nrmLen, "byteLength": uvLen, "target": 34962],
                ["buffer": 0, "byteOffset": posLen + nrmLen + uvLen, "byteLength": idxLen, "target": 34963],
                ["buffer": 0, "byteOffset": imageOffset, "byteLength": jpeg.count],
            ],
            "accessors": [
                [
                    "bufferView": 0,
                    "componentType": 5126,
                    "count": 24,
                    "type": "VEC3",
                    "min": [Double(-hw), Double(-hh), Double(-ht)],
                    "max": [Double(hw), Double(hh), Double(ht)],
                ],
                ["bufferView": 1, "componentType": 5126, "count": 24, "type": "VEC3"],
                ["bufferView": 2, "componentType": 5126, "count": 24, "type": "VEC2"],
                ["bufferView": 3, "componentType": 5123, "count": 36, "type": "SCALAR"],
            ],
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        var jsonPadded = jsonData
        while jsonPadded.count % 4 != 0 {
            jsonPadded.append(0x20) // space
        }

        var glb = Data()
        let totalLength = 12 + 8 + jsonPadded.count + 8 + bin.count
        glb.appendUInt32(0x4654_6C67) // glTF
        glb.appendUInt32(2)
        glb.appendUInt32(UInt32(totalLength))
        glb.appendUInt32(UInt32(jsonPadded.count))
        glb.appendUInt32(0x4E4F_534A) // JSON
        glb.append(jsonPadded)
        glb.appendUInt32(UInt32(bin.count))
        glb.appendUInt32(0x004E_4942) // BIN\0
        glb.append(bin)
        return glb
    }

    enum ExportError: LocalizedError {
        case imageEncodingFailed

        var errorDescription: String? {
            "No se pudo codificar la textura del GLB."
        }
    }
}
