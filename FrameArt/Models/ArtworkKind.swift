import Foundation

enum ArtworkKind: String, Codable, CaseIterable, Identifiable {
    case paintingPhoto
    case scan3D

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paintingPhoto: "Pintura (foto)"
        case .scan3D: "Escaneo 3D"
        }
    }

    var systemImage: String {
        switch self {
        case .paintingPhoto: "photo.artframe"
        case .scan3D: "cube.transparent"
        }
    }
}
