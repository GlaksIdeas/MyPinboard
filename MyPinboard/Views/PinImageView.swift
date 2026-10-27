import SwiftUI

/// Displays a pin's photo, or a placeholder if it has none.
struct PinImageView: View {
    let data: Data?

    var body: some View {
        if let image = Self.makeImage(from: data) {
            image
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "pin.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    static func makeImage(from data: Data?) -> Image? {
        guard let data else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}
