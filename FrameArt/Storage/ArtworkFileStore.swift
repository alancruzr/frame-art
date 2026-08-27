import Foundation
import UIKit

enum ArtworkFileStore {
    private static let folderName = "Artworks"

    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.applicationSupportDirectory
        let root = base
            .appendingPathComponent("FrameArt", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func directory(for pieceID: UUID) -> URL {
        let dir = applicationSupport.appendingPathComponent(pieceID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(for piece: ArtworkPiece, named fileName: String) -> URL {
        directory(for: piece.id).appendingPathComponent(fileName)
    }

    static func imageURL(for piece: ArtworkPiece) -> URL? {
        guard let name = piece.imageFileName else { return nil }
        return fileURL(for: piece, named: name)
    }

    static func usdzURL(for piece: ArtworkPiece) -> URL? {
        guard let name = piece.usdzFileName else { return nil }
        let url = fileURL(for: piece, named: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func glbURL(for piece: ArtworkPiece) -> URL? {
        guard let name = piece.glbFileName else { return nil }
        let url = fileURL(for: piece, named: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func loadImage(for piece: ArtworkPiece) -> UIImage? {
        guard let url = imageURL(for: piece) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    @discardableResult
    static func saveJPEG(_ image: UIImage, for pieceID: UUID, fileName: String = "image.jpg") throws -> String {
        let url = directory(for: pieceID).appendingPathComponent(fileName)
        let flattened = image.normalizedUpright()
        guard let data = flattened.jpegData(compressionQuality: 0.92) else {
            throw StoreError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
        return fileName
    }

    @discardableResult
    static func copyFile(from source: URL, for pieceID: UUID, fileName: String) throws -> String {
        let dest = directory(for: pieceID).appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        return fileName
    }

    static func deleteFiles(for piece: ArtworkPiece) {
        let dir = applicationSupport.appendingPathComponent(piece.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    enum StoreError: LocalizedError {
        case imageEncodingFailed

        var errorDescription: String? {
            "No se pudo guardar la imagen."
        }
    }
}

extension UIImage {
    func normalizedUpright() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scaleFactor = maxDimension / longest
        let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
