import Foundation
import OSLog

/// Errores no fatales: siempre al log unificado y, si Firebase está configurado, a Crashlytics.
/// Nunca incluir títulos, nombres, slugs ni URLs en `context`.
@MainActor
enum ErrorReporter {
    private static let logger = Logger(subsystem: "app.framestudio.ios", category: "Errors")
    static var sinks: [(Error, String) -> Void] = []

    static func record(_ error: Error, context: String) {
        logger.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        for sink in sinks { sink(error, context) }
    }
}

/// Bajas de publicación que fallaron (sin red, servidor caído). Se reintentan al abrir la app
/// para que un enlace de una obra borrada no siga público.
@MainActor
enum PendingUnpublish {
    static let key = "pendingUnpublish.v1"

    static var items: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(studio: String, artwork: String) {
        let item = "\(studio)/\(artwork)"
        var list = items
        guard !list.contains(item) else { return }
        list.append(item)
        UserDefaults.standard.set(Array(list.suffix(100)), forKey: key)
    }

    static func remove(_ item: String) {
        UserDefaults.standard.set(items.filter { $0 != item }, forKey: key)
    }

    static func retryAll() async {
        for item in items {
            let parts = item.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { remove(item); continue }
            if await ArtworkPublisher.unpublish(studio: parts[0], artwork: parts[1]) {
                remove(item)
            }
        }
    }
}
