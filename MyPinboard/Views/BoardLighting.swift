import SwiftUI

extension EnvironmentValues {
    /// Stops board lights from animating, for small thumbnails and exported images.
    @Entry var boardLightingPaused = false
}

/// How a board is lit.
nonisolated enum BoardLighting: String, CaseIterable, Identifiable, Codable {
    case off
    case ambientGlow
    case ledStrip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .ambientGlow: "Ambient Glow"
        case .ledStrip: "LED Lights"
        }
    }
}

/// Light colors a board can use. Rainbow slowly cycles through hues.
nonisolated enum LightColor: String, CaseIterable, Identifiable, Codable {
    case warmWhite
    case coolWhite
    case red
    case amber
    case green
    case blue
    case purple
    case pink
    case rainbow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmWhite: "Warm White"
        case .coolWhite: "Cool White"
        case .red: "Red"
        case .amber: "Amber"
        case .green: "Green"
        case .blue: "Blue"
        case .purple: "Purple"
        case .pink: "Pink"
        case .rainbow: "Rainbow"
        }
    }

    var isAnimated: Bool { self == .rainbow }

    /// `phase` (0...1, wrapping) only affects the rainbow.
    func color(phase: Double = 0) -> Color {
        switch self {
        case .warmWhite: Color(red: 1.0, green: 0.82, blue: 0.55)
        case .coolWhite: Color(red: 0.85, green: 0.93, blue: 1.0)
        case .red: Color(red: 1.0, green: 0.2, blue: 0.2)
        case .amber: Color(red: 1.0, green: 0.62, blue: 0.1)
        case .green: Color(red: 0.2, green: 1.0, blue: 0.4)
        case .blue: Color(red: 0.25, green: 0.5, blue: 1.0)
        case .purple: Color(red: 0.65, green: 0.3, blue: 1.0)
        case .pink: Color(red: 1.0, green: 0.3, blue: 0.7)
        case .rainbow: Color(hue: phase - phase.rounded(.down), saturation: 0.85, brightness: 1)
        }
    }

    /// A swatch fill for pickers.
    var swatch: AnyShapeStyle {
        guard self == .rainbow else { return AnyShapeStyle(color()) }
        return AnyShapeStyle(AngularGradient(colors: Self.rainbowColors(), center: .center))
    }

    static func rainbowColors() -> [Color] {
        (0...6).map { LightColor.rainbow.color(phase: Double($0) / 6) }
    }

    /// A fill for glows: solid, or a slowly rotating gradient for the rainbow.
    func fill(at time: Double) -> AnyShapeStyle {
        guard self == .rainbow else { return AnyShapeStyle(color()) }
        return AnyShapeStyle(
            AngularGradient(colors: Self.rainbowColors(), center: .center, angle: .degrees(time * 25))
        )
    }
}

/// A soft colored glow bleeding in from the board's edges, gently breathing.
struct BoardGlow: View {
    let color: LightColor
    /// Overall brightness, 0...1.
    let strength: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.boardLightingPaused) private var lightingPaused

    /// Lights hold still for Reduce Motion, thumbnails, and exported images.
    private var isStill: Bool { reduceMotion || lightingPaused }
    @State private var isBright = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !color.isAnimated || isStill)) { timeline in
            let time = isStill ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Rectangle()
                .strokeBorder(color.fill(at: time), lineWidth: 80)
                .blur(radius: 40)
        }
        .opacity(strength * (isBright ? 1 : 0.7))
        .blendMode(.screen)
        .allowsHitTesting(false)
        .onAppear {
            guard !isStill else {
                isBright = true
                return
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isBright = true
            }
        }
    }

}

/// Light spilling past the board's edge onto the screen behind it. Place it as the board's background.
struct BoardHalo: View {
    let color: LightColor
    /// Overall brightness, 0...1.
    let strength: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.boardLightingPaused) private var lightingPaused

    /// Lights hold still for Reduce Motion, thumbnails, and exported images.
    private var isStill: Bool { reduceMotion || lightingPaused }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !color.isAnimated || isStill)) { timeline in
            let time = isStill ? 0 : timeline.date.timeIntervalSinceReferenceDate
            RoundedRectangle(cornerRadius: BoardMetrics.cornerRadius, style: .continuous)
                .fill(color.fill(at: time))
                .blur(radius: 28)
        }
        .opacity(strength)
        .allowsHitTesting(false)
    }
}

/// A string of LED bulbs running around the board's perimeter.
struct BoardLEDStrip: View {
    let color: LightColor
    /// Distance from the board's edge to the line the bulbs sit on.
    let inset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.boardLightingPaused) private var lightingPaused

    /// Lights hold still for Reduce Motion, thumbnails, and exported images.
    private var isStill: Bool { reduceMotion || lightingPaused }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !color.isAnimated || isStill)) { timeline in
            Canvas { context, size in
                let time = isStill ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let bulbs = Self.positions(in: size, inset: inset)
                let count = Double(max(bulbs.count, 1))

                func bulbColor(_ index: Int) -> Color {
                    color.color(phase: Double(index) / count + time * 0.08)
                }

                // Halo behind the bulbs.
                context.drawLayer { halo in
                    halo.addFilter(.blur(radius: 6))
                    for (index, point) in bulbs.enumerated() {
                        let rect = CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)
                        halo.fill(Path(ellipseIn: rect), with: .color(bulbColor(index).opacity(0.7)))
                    }
                }

                // Bright bulb with a small highlight.
                for (index, point) in bulbs.enumerated() {
                    let bulb = CGRect(x: point.x - 3.2, y: point.y - 3.2, width: 6.4, height: 6.4)
                    context.fill(Path(ellipseIn: bulb), with: .color(bulbColor(index)))
                    let shine = CGRect(x: point.x - 1.9, y: point.y - 1.9, width: 2.6, height: 2.6)
                    context.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.85)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Evenly spaced points walking clockwise around the board's rounded outline, `inset` points in.
    private static func positions(in size: CGSize, inset: CGFloat) -> [CGPoint] {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return [] }

        let radius = min(max(BoardMetrics.cornerRadius - inset, 0), min(rect.width, rect.height) / 2)
        let straightX = rect.width - 2 * radius
        let straightY = rect.height - 2 * radius
        let arc = radius * .pi / 2

        // Each side and corner in clockwise order, as (length, point at distance along it).
        let segments: [(length: CGFloat, point: (CGFloat) -> CGPoint)] = [
            (straightX, { CGPoint(x: rect.minX + radius + $0, y: rect.minY) }),
            (arc, { Self.cornerPoint(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: -.pi / 2, distance: $0) }),
            (straightY, { CGPoint(x: rect.maxX, y: rect.minY + radius + $0) }),
            (arc, { Self.cornerPoint(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, startAngle: 0, distance: $0) }),
            (straightX, { CGPoint(x: rect.maxX - radius - $0, y: rect.maxY) }),
            (arc, { Self.cornerPoint(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, startAngle: .pi / 2, distance: $0) }),
            (straightY, { CGPoint(x: rect.minX, y: rect.maxY - radius - $0) }),
            (arc, { Self.cornerPoint(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: .pi, distance: $0) })
        ]

        let perimeter = segments.reduce(0) { $0 + $1.length }
        let count = max(Int(perimeter / 22), 8)

        return (0..<count).map { index in
            var distance = perimeter * CGFloat(index) / CGFloat(count)
            for segment in segments {
                if distance < segment.length {
                    return segment.point(distance)
                }
                distance -= segment.length
            }
            return CGPoint(x: rect.minX + radius, y: rect.minY)
        }
    }

    /// A point `distance` along a quarter-circle arc that starts at `startAngle`.
    private static func cornerPoint(center: CGPoint, radius: CGFloat, startAngle: CGFloat, distance: CGFloat) -> CGPoint {
        let angle = radius > 0 ? startAngle + distance / radius : startAngle
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}
