import SwiftUI

/// Selectable surfaces for the board.
nonisolated enum BoardStyle: String, CaseIterable, Identifiable, Codable {
    case cork
    case felt
    case slate
    case linen
    /// The board's own uploaded photo.
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cork: "Cork"
        case .felt: "Green Felt"
        case .slate: "Slate"
        case .linen: "Linen"
        case .custom: "My Photo"
        }
    }

    /// Built-in surfaces; `.custom` only applies once a photo has been uploaded.
    static var presets: [BoardStyle] {
        allCases.filter { $0 != .custom }
    }
}

/// Shows an image from raw data, filling its frame. Decodes once rather than on every redraw.
struct DataImage: View {
    let data: Data?

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: data) {
            image = PinImageView.makeImage(from: data)
        }
    }
}

/// Draws the surface for a board style.
struct BoardBackground: View {
    let style: BoardStyle
    /// The uploaded photo, used when `style` is `.custom`.
    var customData: Data?

    var body: some View {
        switch style {
        case .custom:
            if let customData {
                ZStack {
                    Color.clear.overlay { DataImage(data: customData) }
                        .clipped()
                    // Same soft vignette as the cork, so uploaded photos get some depth too.
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.22)],
                        center: .center,
                        startRadius: 100,
                        endRadius: 700
                    )
                }
            } else {
                CorkTexture()
            }
        case .cork:
            CorkTexture()
        case .felt:
            SpeckledTexture(
                base: [Color(red: 0.12, green: 0.38, blue: 0.24), Color(red: 0.08, green: 0.28, blue: 0.17)],
                speckles: [.white.opacity(0.07), .black.opacity(0.12)],
                count: 2500,
                sizeRange: 0.6...1.4
            )
        case .slate:
            SpeckledTexture(
                base: [Color(red: 0.26, green: 0.28, blue: 0.31), Color(red: 0.16, green: 0.18, blue: 0.2)],
                speckles: [.white.opacity(0.06), .black.opacity(0.18)],
                count: 1800,
                sizeRange: 0.8...2.2
            )
        case .linen:
            SpeckledTexture(
                base: [Color(red: 0.86, green: 0.82, blue: 0.74), Color(red: 0.78, green: 0.73, blue: 0.64)],
                speckles: [.white.opacity(0.25), .brown.opacity(0.12)],
                count: 2500,
                sizeRange: 0.6...1.6
            )
        }
    }
}

/// Real cork photo texture with a soft vignette.
private struct CorkTexture: View {
    var body: some View {
        ZStack {
            // Seamless photographed cork (ambientCG Cork002, CC0), tiled across the board.
            Rectangle()
                .fill(ImagePaint(image: Image("CorkTexture"), scale: 0.5))

            // Soft vignette to give the surface depth.
            RadialGradient(
                colors: [.clear, .black.opacity(0.28)],
                center: .center,
                startRadius: 100,
                endRadius: 700
            )
        }
    }
}

/// Generic gradient with scattered speckles, used for the non-cork surfaces.
private struct SpeckledTexture: View {
    let base: [Color]
    let speckles: [Color]
    let count: Int
    let sizeRange: ClosedRange<Double>

    var body: some View {
        ZStack {
            LinearGradient(colors: base, startPoint: .top, endPoint: .bottom)

            Canvas { context, size in
                var rng = SeededGenerator(seed: 7)
                for _ in 0..<count {
                    let x = Double.random(in: 0...size.width, using: &rng)
                    let y = Double.random(in: 0...size.height, using: &rng)
                    let s = Double.random(in: sizeRange, using: &rng)
                    let tone = speckles[Int.random(in: 0..<speckles.count, using: &rng)]
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(tone))
                }
            }

            RadialGradient(
                colors: [.clear, .black.opacity(0.22)],
                center: .center,
                startRadius: 100,
                endRadius: 700
            )
        }
    }
}

/// Wooden shadowbox frame with a recessed inner shadow, drawn around the board.
struct ShadowboxFrame: View {
    private let frameWidth = BoardMetrics.frameWidth
    private let shape = RoundedRectangle(cornerRadius: BoardMetrics.cornerRadius, style: .continuous)

    var body: some View {
        ZStack {
            // Wood frame.
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.28, blue: 0.14),
                            Color(red: 0.30, green: 0.17, blue: 0.08),
                            Color(red: 0.40, green: 0.24, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: frameWidth
                )

            // Bevel highlight on the outer edge.
            shape
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)

            // Thin dark lip where the frame meets the recessed back panel.
            shape
                .inset(by: frameWidth)
                .strokeBorder(.black.opacity(0.55), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

/// Inner shadow cast by the frame's walls onto the board surface, giving the shadowbox its depth.
struct ShadowboxDepth: View {
    var body: some View {
        RoundedRectangle(cornerRadius: BoardMetrics.cornerRadius, style: .continuous)
            .strokeBorder(.black.opacity(0.55), lineWidth: 40)
            .blur(radius: 16)
            .allowsHitTesting(false)
    }
}

/// Shared board geometry so the surface, frame, and lights all follow the same rounded outline.
enum BoardMetrics {
    static let cornerRadius: CGFloat = 28
    static let frameWidth: CGFloat = 18

    /// A pin's size at scale 1, as a share of the board's width. Relative, so a board looks the same
    /// whether it's full screen, a thumbnail, or on a bigger device. (About 90 points on a phone.)
    static let pinBaseFraction: CGFloat = 0.25

    static func pinBaseSize(in board: CGSize) -> CGFloat {
        max(board.width * pinBaseFraction, 16)
    }

    /// How far in from the board's edge pins must stay: past the wooden frame and lights when there is
    /// one, which are drawn on top of the board's edge and would otherwise hide part of a pin.
    static func pinEdgeInset(showShadowbox: Bool) -> CGFloat {
        showShadowbox ? frameWidth + 6 : 6
    }

    /// Where a pin's center is drawn, in board coordinates. A pin whose saved position is near an edge
    /// is nudged inward so the whole pin stays visible, at any board shape or pin size. `inset` is the
    /// margin to keep clear at every edge.
    static func pinCenter(x: Double, y: Double, scale: Double, in board: CGSize, inset: CGFloat = 0) -> CGPoint {
        let half = pinBaseSize(in: board) * scale / 2
        func place(_ fraction: Double, _ length: CGFloat) -> CGFloat {
            let wanted = fraction * length
            let low = inset + half
            let high = length - inset - half
            // A pin too big for the space is just centered.
            guard high > low else { return length / 2 }
            return min(max(wanted, low), high)
        }
        return CGPoint(x: place(x, board.width), y: place(y, board.height))
    }
}
