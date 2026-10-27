import SwiftUI
import ImageIO
import UniformTypeIdentifiers

extension UUID {
    /// A number made from the ID that stays the same between launches, for repeatable randomness.
    /// (`hashValue` changes every launch.)
    var stableSeed: UInt64 {
        var seed: UInt64 = 0
        withUnsafeBytes(of: uuid) { bytes in
            for byte in bytes.prefix(8) {
                seed = seed << 8 | UInt64(byte)
            }
        }
        return seed
    }
}

/// A pin's photo, with a shimmer over it when the pin is glittery. The shimmer only shows on the pin itself,
/// not on the transparent space around it.
struct PinFaceView: View {
    let data: Data?
    var isShimmery = false
    var seed = UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE") ?? UUID()

    var body: some View {
        PinImageView(data: data)
            .overlay {
                if isShimmery {
                    GlitterOverlay(seed: seed)
                        .mask { PinImageView(data: data) }
                }
            }
    }
}

/// A sweeping glint plus twinkling sparkles and a fine glitter grain, like a glittery enamel pin catching
/// the light. Each pin's sparkles sit in their own places, fixed by its ID, so they don't jump between redraws.
struct GlitterOverlay: View {
    let seed: UUID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.boardLightingPaused) private var lightingPaused

    /// Holds still for Reduce Motion, thumbnails, and exported images.
    private var isStill: Bool { reduceMotion || lightingPaused }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: isStill)) { timeline in
            let time = isStill ? 1.3 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                draw(into: &context, size: size, time: time)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(into context: inout GraphicsContext, size: CGSize, time: Double) {
        let seedValue = seed.stableSeed

        // A soft diagonal glint that sweeps across, then pauses before the next pass.
        let offset = Double(seedValue % 100) / 100 * 3.4
        let cycle = (time + offset).truncatingRemainder(dividingBy: 3.4) / 3.4
        let progress = cycle * 1.6 - 0.3
        var glint = context
        glint.translateBy(x: size.width * progress, y: 0)
        glint.rotate(by: .degrees(18))
        let half = size.width * 0.16
        glint.fill(
            Path(CGRect(x: -half, y: -size.height * 2, width: half * 2, height: size.height * 5)),
            with: .linearGradient(
                Gradient(colors: [.clear, .white.opacity(0.8), .clear]),
                startPoint: CGPoint(x: -half, y: 0),
                endPoint: CGPoint(x: half, y: 0)
            )
        )

        var generator = SeededGenerator(seed: seedValue)

        // Fine glitter grain: lots of tiny specks that wink on and off in pastel colors.
        for _ in 0..<46 {
            let x = Double.random(in: 0...size.width, using: &generator)
            let y = Double.random(in: 0...size.height, using: &generator)
            let radius = Double.random(in: 0.7...1.7, using: &generator)
            let phase = Double.random(in: 0...(2 * .pi), using: &generator)
            let speed = Double.random(in: 1.5...3.5, using: &generator)
            let hue = Double.random(in: 0...1, using: &generator)
            let wink = pow(max(0, sin(time * speed + phase)), 3)
            guard wink > 0.02 else { continue }
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color(hue: hue, saturation: 0.3, brightness: 1).opacity(0.25 + 0.7 * wink))
            )
        }

        // Bigger four-pointed sparkles that grow and fade.
        for _ in 0..<9 {
            let x = Double.random(in: 0...size.width, using: &generator)
            let y = Double.random(in: 0...size.height, using: &generator)
            let radius = size.width * Double.random(in: 0.05...0.1, using: &generator)
            let phase = Double.random(in: 0...(2 * .pi), using: &generator)
            let speed = Double.random(in: 1.0...2.2, using: &generator)
            let twinkle = pow(max(0, sin(time * speed + phase)), 5)
            guard twinkle > 0.02 else { continue }
            context.fill(
                sparkle(center: CGPoint(x: x, y: y), radius: radius * (0.3 + 0.7 * twinkle)),
                with: .color(.white.opacity(0.95 * twinkle))
            )
        }
    }

    /// A four-pointed star.
    private func sparkle(center: CGPoint, radius: Double) -> Path {
        var path = Path()
        let inner = radius * 0.2
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4 - .pi / 2
            let length = index.isMultiple(of: 2) ? radius : inner
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle) * length),
                y: center.y + CGFloat(sin(angle) * length)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// Generated sample pin photos, for previews and testing: a book cover and the same book opened flat.
@MainActor
enum PinArtSamples {
    /// A closed book pin: a red cover with a gold border and a star.
    static var cover: Data? {
        png(width: 200, height: 200) {
            cover(width: 200)
        }
    }

    /// The same book open: the inside of the cover on the left, the inside page on the right.
    static var spread: Data? {
        png(width: 400, height: 200) {
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.12, green: 0.42, blue: 0.46))
                    VStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(.white.opacity(0.35)).frame(width: 110, height: 8)
                        }
                    }
                }
                .padding(8)
                .frame(width: 200, height: 200)

                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.97, green: 0.92, blue: 0.80))
                    VStack(spacing: 12) {
                        Image(systemName: "leaf.fill").font(.system(size: 54)).foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.3))
                        Capsule().fill(.black.opacity(0.25)).frame(width: 100, height: 8)
                        Capsule().fill(.black.opacity(0.25)).frame(width: 80, height: 8)
                    }
                }
                .padding(8)
                .frame(width: 200, height: 200)
            }
        }
    }

    private static func cover(width: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.72, green: 0.16, blue: 0.2))
            RoundedRectangle(cornerRadius: 10).strokeBorder(Color(red: 0.95, green: 0.78, blue: 0.3), lineWidth: 5).padding(14)
            Image(systemName: "star.fill").font(.system(size: 60)).foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.3))
        }
        .padding(8)
        .frame(width: width, height: width)
    }

    private static func png<V: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> V) -> Data? {
        let renderer = ImageRenderer(content: content().frame(width: width, height: height))
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        let output = NSMutableData()
        let target: CFMutableData = output
        guard let destination = CGImageDestinationCreateWithData(target, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

#Preview("Book opening, and glitter") {
    let cover = PinArtSamples.cover
    let spread = PinArtSamples.spread
    return VStack(spacing: 28) {
        // The swing at several points: closed, early, past halfway, and open.
        HStack(alignment: .top, spacing: 36) {
            ForEach([0.0, 0.3, 0.6, 1.0], id: \.self) { progress in
                BookPinArt(
                    progress: progress,
                    closedData: cover,
                    openData: spread,
                    isShimmery: false,
                    seed: UUID(),
                    side: 56
                )
                .frame(width: 56, height: 56)
            }
        }
        .padding(.leading, 60)
        .padding(.top, 20)

        // Glitter on a placeholder pin, and on the book cover.
        HStack(spacing: 24) {
            PinFaceView(data: nil, isShimmery: true, seed: UUID())
                .frame(width: 110, height: 110)
            PinFaceView(data: cover, isShimmery: true, seed: UUID())
                .frame(width: 110, height: 110)
            PinFaceView(data: cover, isShimmery: false)
                .frame(width: 110, height: 110)
        }
    }
    .padding()
    .background(BoardBackground(style: .cork))
}

/// A pin on a board: its photo, glittery if it is, and opening like a book if it does.
///
/// A book pin's closed photo sits over the right-hand page of its open photo. Opening swings the cover
/// out to the left on its hinge, revealing both pages, and the pin slides over to stay centered.
struct PinArt: View {
    let imageData: Data?
    var openImageData: Data?
    var opensLikeBook = false
    var isOpen = false
    var isShimmery = false
    let seed: UUID
    /// The closed pin's side length.
    let side: CGFloat

    var body: some View {
        Group {
            if opensLikeBook, openImageData != nil {
                BookPinArt(
                    progress: isOpen ? 1 : 0,
                    closedData: imageData,
                    openData: openImageData,
                    isShimmery: isShimmery,
                    seed: seed,
                    side: side
                )
                .animation(.spring(duration: 0.8, bounce: 0.2), value: isOpen)
            } else {
                PinFaceView(data: imageData, isShimmery: isShimmery, seed: seed)
            }
        }
        .frame(width: side, height: side)
    }
}

/// The open-book animation. `progress` runs from 0 (closed) to 1 (open) and is animatable, so the cover's
/// front and back swap at the halfway point of the swing rather than at the start.
private struct BookPinArt: View, Animatable {
    var progress: Double
    let closedData: Data?
    let openData: Data?
    let isShimmery: Bool
    let seed: UUID
    let side: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private enum Half {
        case leading
        case trailing
    }

    var body: some View {
        let angle = -180 * progress

        ZStack(alignment: .topLeading) {
            // The inside right page, uncovered as the cover lifts.
            page(.trailing)
                .opacity(progress > 0.01 ? 1 : 0)

            // The cover, hinged on its left edge. Past halfway you're seeing its back, which is the
            // inside left page; it's drawn flipped so it reads correctly once it has swung over.
            ZStack {
                if angle > -90 {
                    PinFaceView(data: closedData, isShimmery: isShimmery, seed: seed)
                } else {
                    page(.leading)
                        .scaleEffect(x: -1, y: 1)
                }
            }
            .frame(width: side, height: side)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
        }
        .frame(width: side, height: side, alignment: .topLeading)
        // Slides right as it opens, so the open spread ends up centered where the closed pin was.
        .offset(x: side / 2 * progress)
    }

    /// One page of the open photo, which shows both pages side by side.
    private func page(_ half: Half) -> some View {
        PinFaceView(data: openData, isShimmery: isShimmery, seed: seed)
            .frame(width: side * 2, height: side)
            .frame(width: side, height: side, alignment: half == .leading ? .leading : .trailing)
            .clipped()
    }
}
