import Foundation
import UIKit

/// Writes the pair of share files: USDZ (iOS Quick Look) and GLB (Android Scene Viewer / model-viewer).
enum ArtworkExporter {
    static let usdzFileName = "model.usdz"
    static let glbFileName = "model.glb"

    static func exportShareMeshes(for piece: ArtworkPiece) throws {
        switch piece.kind {
        case .paintingPhoto:
            guard let image = ArtworkFileStore.loadImage(for: piece) else {
                throw ExporterError.missingImage
            }
            let usdzURL = ArtworkFileStore.fileURL(for: piece, named: usdzFileName)
            let glbURL = ArtworkFileStore.fileURL(for: piece, named: glbFileName)
            try USDZExporter.exportPainting(
                image: image,
                widthCentimeters: piece.widthCentimeters,
                title: piece.title,
                to: usdzURL
            )
            try GLBExporter.exportPainting(
                image: image,
                widthCentimeters: piece.widthCentimeters,
                title: piece.title,
                to: glbURL
            )
            piece.usdzFileName = usdzFileName
            piece.glbFileName = glbFileName
        case .scan3D:
            // Imported USDZ/Reality is already a 3D asset. GLB would need a USD parser.
            break
        }
    }

    enum ExporterError: LocalizedError {
        case missingImage

        var errorDescription: String? {
            "Esta obra no tiene una foto para exportar."
        }
    }
}
