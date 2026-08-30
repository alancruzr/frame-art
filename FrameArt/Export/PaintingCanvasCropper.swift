import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit
import Vision

#if canImport(CoreAIImageSegmenter)
import CoreAIImageSegmenter
#endif

/// On-device canvas isolation for a photo of a painting.
///
/// Order:
/// 1. iOS 27 + Core AI SAM 3 (`CoreAIImageSegmenter.ImageSegmenter`) when the model bundle is present.
/// 2. `VNDetectRectanglesRequest` + `CIFilter.perspectiveCorrection()`.
/// 3. `VNGenerateForegroundInstanceMaskRequest` (subject lifting).
/// 4. Original photo.
///
/// SAM 3 is not in the iPhoneOS 26 SDK. The Core AI path is compiled only when
/// `CoreAIImageSegmenter` can be imported (Xcode 27+) and is runtime-gated with
/// `@available(iOS 27, *)`.
///
/// Place the SAM 3 bundle from apple/coreai-models (`models/sam3` export: a folder
/// with `metadata.json`, the `.aimodel`, and `tokenizer/`) at either:
/// - App bundle resource named `SAM3`
/// - `Application Support/FrameArt/Models/SAM3`
/// The float16 bundle is ~1.7 GB, so it is not vendored. Missing bundle → Vision.
enum PaintingCanvasCropper: Sendable {
    struct CropResult: Sendable {
        let image: UIImage
        let didCrop: Bool
        let method: Method
    }

    enum Method: String, Sendable {
        case sam3
        case rectangle
        case foregroundMask
        case original
    }

    /// Isolates the painting canvas. Never throws; returns the original on failure.
    static func cropCanvas(from image: UIImage) async -> CropResult {
        await cropCanvas(from: image, progress: { _ in })
    }

    static func cropCanvas(
        from image: UIImage,
        progress: @escaping @Sendable (String) -> Void
    ) async -> CropResult {
        let upright = image.normalizedUpright()

        #if canImport(CoreAIImageSegmenter)
        if #available(iOS 27, *) {
            progress("Preparando recorte…")
            if let sam = await cropWithSAM3(upright) {
                return CropResult(image: sam, didCrop: true, method: .sam3)
            }
        }
        #endif

        progress("Recortando el lienzo…")
        return await Task.detached(priority: .userInitiated) {
            cropWithVision(upright)
        }.value
    }

    // MARK: - Vision (iOS 26 and SAM 3 fallback)

    nonisolated private static func cropWithVision(_ image: UIImage) -> CropResult {
        if let rectified = cropWithDetectedRectangle(image) {
            return CropResult(image: rectified, didCrop: true, method: .rectangle)
        }
        if let lifted = cropWithForegroundMask(image) {
            return CropResult(image: lifted, didCrop: true, method: .foregroundMask)
        }
        return CropResult(image: image, didCrop: false, method: .original)
    }

    nonisolated private static func cropWithDetectedRectangle(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.45
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 25
        request.minimumSize = 0.15
        request.maximumObservations = 8

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let observations = (request.results ?? []).filter { observation in
            let area = observation.boundingBox.width * observation.boundingBox.height
            return observation.confidence >= 0.45 && area >= 0.15 && area <= 0.95
        }
        guard let best = observations.max(by: { lhs, rhs in
            let areaL = lhs.boundingBox.width * lhs.boundingBox.height
            let areaR = rhs.boundingBox.width * rhs.boundingBox.height
            if abs(areaL - areaR) > 0.02 { return areaL < areaR }
            return lhs.confidence < rhs.confidence
        }) else {
            return nil
        }

        return applyPerspectiveCorrection(image, observation: best)
    }

    nonisolated private static func applyPerspectiveCorrection(
        _ image: UIImage,
        observation: VNRectangleObservation
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = ciPoint(fromNormalized: observation.topLeft, extent: extent)
        filter.topRight = ciPoint(fromNormalized: observation.topRight, extent: extent)
        filter.bottomRight = ciPoint(fromNormalized: observation.bottomRight, extent: extent)
        filter.bottomLeft = ciPoint(fromNormalized: observation.bottomLeft, extent: extent)
        filter.crop = true

        guard let output = filter.outputImage, !output.extent.isEmpty, output.extent.width > 8, output.extent.height > 8 else {
            return nil
        }
        return render(output, scale: image.scale)
    }

    nonisolated private static func cropWithForegroundMask(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            return nil
        }

        let maskBuffer: CVPixelBuffer
        do {
            maskBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
        } catch {
            return nil
        }

        guard var bounds = opaqueBounds(of: maskBuffer) else { return nil }
        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        bounds = bounds.insetBy(dx: -6, dy: -6).integral.intersection(imageBounds)
        let fraction = (bounds.width * bounds.height) / max(imageBounds.width * imageBounds.height, 1)
        guard fraction >= 0.15, fraction <= 0.95, bounds.width >= 8, bounds.height >= 8 else {
            return nil
        }
        guard let cropped = cgImage.cropping(to: bounds) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    // MARK: - SAM 3 (iOS 27 / Core AI)

    #if canImport(CoreAIImageSegmenter)
    @available(iOS 27, *)
    private static func cropWithSAM3(_ image: UIImage) async -> UIImage? {
        guard let bundleURL = sam3BundleURL(), let cgImage = image.cgImage else { return nil }
        do {
            let segmenter = try await ImageSegmenter(resourcesAt: bundleURL.path)
            for prompt in ["painting", "canvas", "artwork"] {
                let response = try await segmenter.segment(image: cgImage, prompt: prompt)
                if let cropped = cropUsingSAM3Response(image, cgImage: cgImage, response: response) {
                    return cropped
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    @available(iOS 27, *)
    private static func cropUsingSAM3Response(_ image: UIImage, cgImage: CGImage, response: SegmentationResponse) -> UIImage? {
        let pixelBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let pixelArea = pixelBounds.width * pixelBounds.height

        func pixelBox(_ box: CGRect) -> CGRect {
            if box.maxX <= 1.5, box.maxY <= 1.5, box.width <= 1.5, box.height <= 1.5 {
                return CGRect(
                    x: box.origin.x * pixelBounds.width,
                    y: box.origin.y * pixelBounds.height,
                    width: box.width * pixelBounds.width,
                    height: box.height * pixelBounds.height
                )
            }
            return box
        }

        var bestScore: Float = -1
        var bestBox: CGRect = .zero
        for segment in response.segments {
            let box = pixelBox(segment.box).integral.intersection(pixelBounds)
            let fraction = (box.width * box.height) / max(pixelArea, 1)
            guard fraction >= 0.15, fraction <= 0.95, box.width >= 8, box.height >= 8 else { continue }
            if segment.score > bestScore {
                bestScore = segment.score
                bestBox = box
            }
        }
        guard bestScore >= 0 else { return nil }
        let padded = bestBox.insetBy(dx: -6, dy: -6).integral.intersection(pixelBounds)
        guard let cropped = cgImage.cropping(to: padded) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    /// Bundle layout required by `ImageSegmenter(resourcesAt:)` in apple/coreai-models:
    /// `metadata.json` with `kind: "segmenter"`, `assets.main` → `.aimodel`, plus `tokenizer/` for SAM 3.
    private static func sam3BundleURL() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let bundled = Bundle.main.url(forResource: "SAM3", withExtension: nil) {
            candidates.append(bundled)
        }
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("SAM3", isDirectory: true))
            candidates.append(resources.appendingPathComponent("sam3-CoreAI", isDirectory: true))
        }
        let support = (fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.applicationSupportDirectory)
            .appendingPathComponent("FrameArt", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("SAM3", isDirectory: true)
        candidates.append(support)

        return candidates.first { url in
            fm.fileExists(atPath: url.appendingPathComponent("metadata.json").path)
        }
    }
    #endif

    // MARK: - Geometry helpers

    nonisolated private static func ciPoint(fromNormalized point: CGPoint, extent: CGRect) -> CGPoint {
        CGPoint(
            x: extent.origin.x + point.x * extent.width,
            y: extent.origin.y + point.y * extent.height
        )
    }

    nonisolated private static func render(_ ciImage: CIImage, scale: CGFloat) -> UIImage? {
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    nonisolated private static func opaqueBounds(of pixelBuffer: CVPixelBuffer) -> CGRect? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var found = false

        let strideX = max(1, width / 1200)
        let strideY = max(1, height / 1200)

        if format == kCVPixelFormatType_OneComponent32Float {
            let threshold: Float = 0.08
            for y in Swift.stride(from: 0, to: height, by: strideY) {
                let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float.self)
                for x in Swift.stride(from: 0, to: width, by: strideX) {
                    if row[x] > threshold {
                        found = true
                        minX = min(minX, x)
                        minY = min(minY, y)
                        maxX = max(maxX, x)
                        maxY = max(maxY, y)
                    }
                }
            }
        } else {
            let threshold: UInt8 = 20
            for y in Swift.stride(from: 0, to: height, by: strideY) {
                let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
                for x in Swift.stride(from: 0, to: width, by: strideX) {
                    if row[x] > threshold {
                        found = true
                        minX = min(minX, x)
                        minY = min(minY, y)
                        maxX = max(maxX, x)
                        maxY = max(maxY, y)
                    }
                }
            }
        }

        guard found else { return nil }
        // Expand by one stride so sampling does not shrink the canvas.
        minX = max(0, minX - strideX)
        minY = max(0, minY - strideY)
        maxX = min(width - 1, maxX + strideX)
        maxY = min(height - 1, maxY + strideY)
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
