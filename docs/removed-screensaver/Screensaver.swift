import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - The scene

/// A quiet, moonlit woodland that plays when the iPad has been left alone: twinkling stars, a crescent moon,
/// the odd shooting star, fireflies drifting over the hills, and little woodland creatures wandering by.
/// Any touch wakes it.
struct ScreensaverView: View {
    let onWake: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fixed so the hills and the trees on them always line up.
    private let farHills = HillShape(base: 0.60, amplitude: 0.035, wavelength: 0.85, phase: 0.10)
    private let midHills = HillShape(base: 0.71, amplitude: 0.050, wavelength: 0.55, phase: 0.55)
    private let nearGround = HillShape(base: 0.86, amplitude: 0.022, wavelength: 0.70, phase: 0.20)

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let moon = min(size.width, size.height) * 0.13

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.04, blue: 0.14),
                        Color(red: 0.14, green: 0.11, blue: 0.32),
                        Color(red: 0.38, green: 0.25, blue: 0.48)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                NightSky(isStill: reduceMotion)

                Moon(diameter: moon)
                    .position(x: size.width * 0.78, y: size.height * 0.19)

                farHills
                    .fill(Color(red: 0.16, green: 0.14, blue: 0.36))

                midHills
                    .fill(Color(red: 0.09, green: 0.10, blue: 0.26))
                Pines(hill: midHills, seed: 11)

                nearGround
                    .fill(Color(red: 0.17, green: 0.23, blue: 0.40))

                Fireflies(isStill: reduceMotion)

                ScreensaverCritters()
                    .frame(height: size.height * 0.30)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Text("Touch to wake")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // Wakes on the first touch down, rather than waiting for a tap to finish.
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in onWake() })
        .accessibilityLabel("Screensaver. Touch to wake.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onWake() }
    }
}

/// Twinkling stars, with a shooting star now and then.
private struct NightSky: View {
    let isStill: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: isStill)) { timeline in
            let time = isStill ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                var generator = SeededGenerator(seed: 2026)
                for _ in 0..<110 {
                    let x = Double.random(in: 0...size.width, using: &generator)
                    let y = Double.random(in: 0...(size.height * 0.62), using: &generator)
                    let radius = Double.random(in: 0.6...2.1, using: &generator)
                    let phase = Double.random(in: 0...(2 * .pi), using: &generator)
                    let speed = Double.random(in: 0.5...2.0, using: &generator)
                    let twinkle = 0.4 + 0.6 * (0.5 + 0.5 * sin(time * speed + phase))
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(twinkle * 0.9))
                    )
                }

                guard !isStill else { return }

                // A shooting star streaks across about every 17 seconds, somewhere new each time.
                let period = 17.0
                let streak = 1.2
                let cycle = time.truncatingRemainder(dividingBy: period)
                guard cycle < streak else { return }

                var streakGenerator = SeededGenerator(seed: UInt64(time / period) &+ 77)
                let startX = Double.random(in: 0.1...0.55, using: &streakGenerator) * size.width
                let startY = Double.random(in: 0.05...0.25, using: &streakGenerator) * size.height
                let progress = cycle / streak
                for step in 0..<14 {
                    let behind = Double(step) * 0.018
                    let along = max(progress - behind, 0)
                    let x = startX + along * size.width * 0.32
                    let y = startY + along * size.height * 0.16
                    let radius = 2.6 * (1 - Double(step) / 14)
                    let fade = (1 - Double(step) / 14) * sin(progress * .pi)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white.opacity(fade))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// A crescent moon with a soft glow.
private struct Moon: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.93, blue: 0.7).opacity(0.35))
                .frame(width: diameter * 2.1, height: diameter * 2.1)
                .blur(radius: diameter * 0.5)

            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.96, blue: 0.8))
                    .frame(width: diameter, height: diameter)
                // The bite taken out of the full circle leaves the crescent.
                Circle()
                    .frame(width: diameter * 0.88, height: diameter * 0.88)
                    .offset(x: diameter * 0.3, y: -diameter * 0.1)
                    .blendMode(.destinationOut)
            }
            .frame(width: diameter, height: diameter)
            .compositingGroup()
        }
        .frame(width: diameter, height: diameter)
    }
}

/// A rolling line of hills, filled down to the bottom of the screen.
private struct HillShape: Shape {
    /// How far down the screen the hills run on average, as a fraction of its height.
    let base: CGFloat
    /// How far they rise and fall, as a fraction of the height.
    let amplitude: CGFloat
    /// How much of the width one rise and fall takes.
    let wavelength: CGFloat
    let phase: CGFloat

    /// The height of the crest at `x`, so things like trees can sit right on it.
    func crest(at x: CGFloat, in rect: CGRect) -> CGFloat {
        let wave = sin((x / rect.width / wavelength + phase) * 2 * .pi)
        return rect.minY + rect.height * (base + amplitude * wave)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        var x = rect.minX
        while x <= rect.maxX {
            path.addLine(to: CGPoint(x: x, y: crest(at: x, in: rect)))
            x += 4
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Pine trees dotted along a line of hills.
private struct Pines: View {
    let hill: HillShape
    let seed: UInt64

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            var generator = SeededGenerator(seed: seed)
            let count = max(Int(size.width / 55), 8)
            for _ in 0..<count {
                let x = Double.random(in: 0...size.width, using: &generator)
                let height = size.height * Double.random(in: 0.05...0.10, using: &generator)
                let ground = hill.crest(at: x, in: rect) + 4
                context.fill(pine(baseX: x, ground: ground, height: height), with: .color(Color(red: 0.05, green: 0.07, blue: 0.19)))
            }
        }
        .allowsHitTesting(false)
    }

    /// Three stacked triangles on a short trunk.
    private func pine(baseX: Double, ground: Double, height: Double) -> Path {
        var path = Path()
        let width = height * 0.55
        let trunk = height * 0.12
        for tier in 0..<3 {
            let tierBottom = ground - trunk - Double(tier) * height * 0.26
            let tierWidth = width * (1 - Double(tier) * 0.25)
            path.move(to: CGPoint(x: baseX - tierWidth / 2, y: tierBottom))
            path.addLine(to: CGPoint(x: baseX, y: tierBottom - height * 0.42))
            path.addLine(to: CGPoint(x: baseX + tierWidth / 2, y: tierBottom))
            path.closeSubpath()
        }
        path.addRect(CGRect(x: baseX - width * 0.06, y: ground - trunk, width: width * 0.12, height: trunk))
        return path
    }
}

/// Fireflies drifting in slow loops, each glowing on its own rhythm.
private struct Fireflies: View {
    let isStill: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: isStill)) { timeline in
            let time = isStill ? 1 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                var generator = SeededGenerator(seed: 515)
                for _ in 0..<28 {
                    let homeX = Double.random(in: 0...size.width, using: &generator)
                    let homeY = Double.random(in: (size.height * 0.45)...(size.height * 0.95), using: &generator)
                    let reachX = Double.random(in: 20...70, using: &generator)
                    let reachY = Double.random(in: 14...46, using: &generator)
                    let driftX = Double.random(in: 0.12...0.35, using: &generator)
                    let driftY = Double.random(in: 0.10...0.30, using: &generator)
                    let phase = Double.random(in: 0...(2 * .pi), using: &generator)
                    let blink = Double.random(in: 0.5...1.4, using: &generator)

                    let x = homeX + sin(time * driftX + phase) * reachX
                    let y = homeY + cos(time * driftY + phase * 1.7) * reachY
                    let glow = pow(0.5 + 0.5 * sin(time * blink + phase * 2), 2)

                    let center = CGPoint(x: x, y: y)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 14, y: y - 14, width: 28, height: 28)),
                        with: .radialGradient(
                            Gradient(colors: [Color(red: 0.85, green: 1.0, blue: 0.45).opacity(0.75 * glow), .clear]),
                            center: center,
                            startRadius: 0,
                            endRadius: 14
                        )
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)),
                        with: .color(Color(red: 1.0, green: 1.0, blue: 0.75).opacity(0.3 + 0.7 * glow))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Woodland creatures strolling across the foreground, one at a time, every few seconds.
private struct ScreensaverCritters: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var critters: [Critter] = []
    @State private var lastKind: CritterKind?

    /// The creatures are drawn at phone scale, then enlarged to suit a big screen.
    private let enlargement: CGFloat = 1.8

    var body: some View {
        GeometryReader { geometry in
            let space = CGSize(width: geometry.size.width / enlargement, height: geometry.size.height / enlargement)
            ZStack {
                ForEach(critters) { critter in
                    CritterView(critter: critter, banner: space, color: .black.opacity(0.8))
                }
            }
            .frame(width: space.width, height: space.height)
            .scaleEffect(enlargement, anchor: .topLeading)
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(1.5))
            while !Task.isCancelled {
                sendOut()
                try? await Task.sleep(for: .seconds(Double.random(in: 5...10)))
            }
        }
    }

    private func sendOut() {
        let options = CritterKind.allCases.filter { $0 != lastKind }
        let kind = options.randomElement() ?? .hare
        lastKind = kind
        let critter = Critter(kind: kind, goesRight: Bool.random(), start: .now, lane: Double.random(in: 0...1))
        critters.append(critter)

        Task {
            try? await Task.sleep(for: .seconds(kind.duration + 1.5))
            critters.removeAll { $0.id == critter.id }
        }
    }
}

#Preview {
    ScreensaverView {}
}

