import Foundation
import LinkPresentation
import UIKit
import SwiftUI

enum ClientViewer {
    static let origin = "https://frame-studio.netlify.app"

    static let customScheme = "framestudio"
    static let host = "frame-studio.netlify.app"

    static func artworkURL(studio: String, artwork: String) -> URL {
        URL(string: "\(origin)/\(studio)/\(artwork)/")!
    }

    static func customURL(studio: String, artwork: String) -> URL {
        URL(string: "\(customScheme)://\(studio)/\(artwork)")!
    }

    /// WhatsApp and the system share sheet get only this HTTPS URL — never a USDZ/GLB file.
    static func shareURL(studio: String, artwork: String) -> URL {
        artworkURL(studio: studio, artwork: artwork)
    }

    /// Parses `/{studio}/{artwork}/` HTTPS Universal Links and `framestudio://{studio}/{artwork}`.
    /// Ignores `/o/UUID`, `/api`, well-known, and static fallbacks.
    static func parseArtworkLink(_ url: URL) -> (studio: String, artwork: String)? {
        let scheme = url.scheme?.lowercased() ?? ""
        var parts: [String] = []
        if scheme == customScheme {
            if let host = url.host, !host.isEmpty {
                parts.append(host)
            }
            parts.append(contentsOf: url.path.split(separator: "/").map(String.init))
        } else if scheme == "https" || scheme == "http" {
            guard let host = url.host?.lowercased(), host == Self.host else { return nil }
            parts = url.path.split(separator: "/").map(String.init)
        } else {
            return nil
        }
        parts = parts.filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }
        let studio = parts[0]
        let artwork = parts[1]
        let reserved: Set<String> = [
            "o", "api", ".well-known", "apple-app-site-association",
            "index.html", "model.usdz", "model.glb", "poster.jpg", "poster.png"
        ]
        if reserved.contains(studio) { return nil }
        guard isSlug(studio), isSlug(artwork) else { return nil }
        return (studio, artwork)
    }

    private static func isSlug(_ value: String) -> Bool {
        guard value.count <= 64 else { return false }
        return value.wholeMatch(of: /^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$/) != nil
    }
}

final class ArtworkLinkActivityItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let image: UIImage?

    init(url: URL, title: String, image: UIImage?) {
        self.url = url
        self.title = title
        self.image = image
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        if let image {
            metadata.imageProvider = NSItemProvider(object: image)
        }
        return metadata
    }
}

struct ArtworkShareSheet: UIViewControllerRepresentable {
    let url: URL
    let title: String
    let image: UIImage?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let item = ArtworkLinkActivityItem(url: url, title: title, image: image)
        let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            let bounds = UIScreen.main.bounds
            popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
