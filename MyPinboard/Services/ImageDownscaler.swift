import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Shrinks photos people upload for walls and boards, so the store doesn't fill up with full-size originals.
nonisolated enum ImageDownscaler {
    /// Re-encodes `data` as a JPEG no larger than `maxDimension` pixels on its longest side.
    /// Respects the photo's orientation. Returns nil if the data isn't a readable image.
    static func jpegData(from data: Data, maxDimension: CGFloat, quality: Double = 0.8) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }

        let encodeOptions: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, encodeOptions as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
