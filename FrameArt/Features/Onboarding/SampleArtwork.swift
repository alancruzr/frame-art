import SwiftUI
import UIKit

/// Obra de ejemplo del onboarding. Dominio público, imagen CC0 de The Met Open Access.
/// Ver docs/sample-artwork-license.md.
enum SampleArtworkInfo {
    static let assetName = "SampleArtwork"
    static let title = "Wheat Field with Cypresses"
    static let artist = "Vincent van Gogh"
    static let year = "1889"
    static let museum = "The Metropolitan Museum of Art"
    static let widthCentimeters: Double = 93.4
    static let heightCentimeters: Double = 73.2
    static let sourceURL = URL(string: "https://www.metmuseum.org/art/collection/search/436535")!
    static let license = "Dominio público (CC0, The Met Open Access)"

    static var credit: String {
        "\(artist), \(title), \(year). \(museum). \(license)."
    }

    static var image: UIImage? { UIImage(named: assetName) }
}

/// Vista de la obra de ejemplo.
struct SampleArtwork: View {
    var body: some View {
        if let image = SampleArtworkInfo.image {
            Image(uiImage: image).resizable().scaledToFill()
                .accessibilityLabel("\(SampleArtworkInfo.title), \(SampleArtworkInfo.artist)")
        } else {
            FrameStudioBrand.softLavender
        }
    }
}
