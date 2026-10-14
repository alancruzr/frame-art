import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// Cuatro esquinas normalizadas (0…1) con origen arriba a la izquierda (coordenadas de UI).
struct CornerQuad: Equatable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let inset = CornerQuad(
        topLeft: CGPoint(x: 0.08, y: 0.08), topRight: CGPoint(x: 0.92, y: 0.08),
        bottomRight: CGPoint(x: 0.92, y: 0.92), bottomLeft: CGPoint(x: 0.08, y: 0.92)
    )
    static let full = CornerQuad(
        topLeft: .zero, topRight: CGPoint(x: 1, y: 0),
        bottomRight: CGPoint(x: 1, y: 1), bottomLeft: CGPoint(x: 0, y: 1)
    )

    var points: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    subscript(index: Int) -> CGPoint {
        get { points[index] }
        set {
            let p = CGPoint(x: min(max(newValue.x, 0), 1), y: min(max(newValue.y, 0), 1))
            switch index {
            case 0: topLeft = p
            case 1: topRight = p
            case 2: bottomRight = p
            default: bottomLeft = p
            }
        }
    }

    /// Vision usa origen abajo a la izquierda.
    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft; self.topRight = topRight; self.bottomRight = bottomRight; self.bottomLeft = bottomLeft
    }

    init(visionObservation o: VNRectangleObservation) {
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        self.init(topLeft: flip(o.topLeft), topRight: flip(o.topRight), bottomRight: flip(o.bottomRight), bottomLeft: flip(o.bottomLeft))
    }
}

extension PaintingCanvasCropper {
    /// Esquinas sugeridas por Vision para precargar el editor manual.
    nonisolated static func detectCorners(in image: UIImage) -> CornerQuad? {
        guard let cgImage = image.normalizedUpright().cgImage else { return nil }
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.3
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 30
        request.minimumSize = 0.1
        request.maximumObservations = 4
        do {
            try VNImageRequestHandler(cgImage: cgImage, orientation: .up).perform([request])
        } catch {
            return nil
        }
        guard let best = (request.results ?? []).max(by: {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        }) else { return nil }
        return CornerQuad(visionObservation: best)
    }

    /// Corrección de perspectiva con las esquinas elegidas (CIPerspectiveCorrection).
    nonisolated static func perspectiveCrop(_ image: UIImage, quad: CornerQuad) -> UIImage? {
        let upright = image.normalizedUpright()
        guard let cgImage = upright.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let e = ciImage.extent
        func ci(_ p: CGPoint) -> CGPoint { CGPoint(x: e.minX + p.x * e.width, y: e.minY + (1 - p.y) * e.height) }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = ci(quad.topLeft)
        filter.topRight = ci(quad.topRight)
        filter.bottomRight = ci(quad.bottomRight)
        filter.bottomLeft = ci(quad.bottomLeft)
        filter.crop = true
        guard let output = filter.outputImage, output.extent.width > 8, output.extent.height > 8,
              let cg = CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: upright.scale, orientation: .up)
    }
}
