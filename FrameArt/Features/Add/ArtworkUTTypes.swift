import UniformTypeIdentifiers

enum ArtworkUTTypes {
    static let usdz: UTType = UTType(filenameExtension: "usdz")
        ?? UTType("com.pixar.universal-scene-description-mobile")
        ?? .data

    static let glb: UTType = UTType(filenameExtension: "glb")
        ?? UTType("model/gltf-binary")
        ?? .data

    static var importable: [UTType] {
        [.image]
    }
}
