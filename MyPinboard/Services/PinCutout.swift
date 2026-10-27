import CoreImage
import Foundation
import ImageIO
import Vision

/// Isolates a pin from its background using Vision's foreground subject detection.
enum PinCutout {
    enum CutoutError: Error {
        case unreadableImage
        case noSubjectFound
        case encodingFailed
    }

    /// Longest edge, in pixels, of the image handed to Vision. Full-resolution
    /// camera photos are far larger than needed and can exhaust image buffers.
    private nonisolated static let maxPixelSize = 2048

    /// Returns PNG data of the photo's main subject on a transparent background,
    /// cropped to the subject's bounds.
    @concurrent
    static func removeBackground(from imageData: Data) async throws -> Data {
        let cgImage = try downsampledImage(from: imageData)
        let handler = ImageRequestHandler(cgImage)
        let request = GenerateForegroundInstanceMaskRequest()

        guard let observation = try await handler.perform(request) else {
            throw CutoutError.noSubjectFound
        }

        let pixelBuffer = try observation.generateMaskedImage(
            for: observation.allInstances,
            imageFrom: handler,
            croppedToInstancesExtent: true
        )

        return try pngData(from: pixelBuffer)
    }

    private nonisolated static func pngData(from pixelBuffer: CVPixelBuffer) throws -> Data {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let png = context.pngRepresentation(
                of: ciImage,
                format: .RGBA8,
                colorSpace: colorSpace
              )
        else {
            throw CutoutError.encodingFailed
        }
        return png
    }

    /// Decodes the photo at a bounded size, with its orientation applied.
    private nonisolated static func downsampledImage(from data: Data) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            throw CutoutError.unreadableImage
        }
        return image
    }
}
