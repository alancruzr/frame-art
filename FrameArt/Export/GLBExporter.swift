import Foundation
import UIKit

/// Minimal glTF 2.0 / GLB writer for a textured vertical plane.
/// Scene Viewer, WebXR and `<model-viewer>` consume this on Android and the web.
enum GLBExporter {
    static func exportPainting(
        image: UIImage,
        widthCentimeters: Double,
        title: String,
        to destination: URL
    ) throws {
        let prepared = image.normalizedUpright().resized(maxDimension: 2048)
        let widthM = Float(widthCentimeters / 100.0)
        let heightM = widthM * Float(prepared.size.height / max(prepared.size.width, 1))

        guard let jpeg = prepared.jpegData(compressionQuality: 0.9) else {
            throw ExportError.imageEncodingFailed
        }

        let glb = try buildGLB(
            jpeg: jpeg,
            halfWidth: widthM / 2,
            halfHeight: heightM / 2,
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
        title: String
    ) throws -> Data {
        var bin = Data()

        func appendFloats(_ values: [Float]) {
            for value in values {
                var bits = value.bitPattern.littleEndian
                Swift.withUnsafeBytes(of: &bits) { bin.append(contentsOf: $0) }
            }
        }

        // POSITION: BL, BR, TR, TL  (Y-up, normal +Z)
        let positions: [Float] = [
            -halfWidth, -halfHeight, 0,
             halfWidth, -halfHeight, 0,
             halfWidth,  halfHeight, 0,
            -halfWidth,  halfHeight, 0,
        ]
        appendFloats(positions)

        // NORMAL
        appendFloats([
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,
        ])

        // TEXCOORD_0 — glTF origin is top-left
        appendFloats([
            0, 1,
            1, 1,
            1, 0,
            0, 0,
        ])

        // INDICES uint16, two triangles, CCW from +Z
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]
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
                ["buffer": 0, "byteOffset": 0, "byteLength": 48, "target": 34962],
                ["buffer": 0, "byteOffset": 48, "byteLength": 48, "target": 34962],
                ["buffer": 0, "byteOffset": 96, "byteLength": 32, "target": 34962],
                ["buffer": 0, "byteOffset": 128, "byteLength": 12, "target": 34963],
                ["buffer": 0, "byteOffset": imageOffset, "byteLength": jpeg.count],
            ],
            "accessors": [
                [
                    "bufferView": 0,
                    "componentType": 5126,
                    "count": 4,
                    "type": "VEC3",
                    "min": [Double(-halfWidth), Double(-halfHeight), 0.0],
                    "max": [Double(halfWidth), Double(halfHeight), 0.0],
                ],
                ["bufferView": 1, "componentType": 5126, "count": 4, "type": "VEC3"],
                ["bufferView": 2, "componentType": 5126, "count": 4, "type": "VEC2"],
                ["bufferView": 3, "componentType": 5123, "count": 6, "type": "SCALAR"],
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
