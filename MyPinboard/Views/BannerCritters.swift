import SwiftUI

extension EnvironmentValues {
    /// Goes up by one each time the page is tugged down past its top. Banners use it to send out a critter.
    @Entry var bannerTug = 0
}

/// The little woodland creatures that scurry across a banner as shadows when it's tugged.
enum CritterKind: CaseIterable {
    case hare, bird, tortoise, lizard, ladybug, hedgehog, fox, owl

    /// Size of the creature's longer side, in points.
    var size: CGFloat {
        switch self {
        case .hare: 40
        case .bird: 36
        case .tortoise: 34
        case .lizard: 34
        case .ladybug: 20
        case .hedgehog: 42
        case .fox: 56
        case .owl: 42
        }
    }

    /// Seconds to cross the banner. Slow creatures take their time.
    var duration: Double {
        switch self {
        case .hare: 3.2
        case .bird: 2.6
        case .tortoise: 7.0
        case .lizard: 2.4
        case .ladybug: 5.5
        case .hedgehog: 5.0
        case .fox: 3.0
        case .owl: 3.4
        }
    }

    /// Whether the creature flies, and so travels high on the banner instead of along its bottom edge.
    var flies: Bool {
        self == .bird || self == .owl
    }

    /// Whether the artwork faces right, as drawn. Creatures facing the other way get flipped.
    /// Every creature here is drawn facing right; the owl faces forward, so which way it flies doesn't matter.
    var facesRight: Bool { true }
}

/// One creature crossing the banner.
struct Critter: Identifiable {
    let id = UUID()
    let kind: CritterKind
    /// Which way it runs. Creatures turn to face where they're going.
    let goesRight: Bool
    /// Where it starts, so two creatures at once don't move in lockstep.
    let start: Date
    /// Varies a flyer's height and a walker's lane a little.
    let lane: Double
}

/// The creatures crossing a banner, in shadow. Sized to the banner it's drawn in.
struct BannerCritters: View {
    @Environment(\.bannerTug) private var tugCount
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var critters: [Critter] = []
    @State private var lastKind: CritterKind?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(critters) { critter in
                    CritterView(critter: critter, banner: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: tugCount) {
            guard !reduceMotion else { return }
            sendOut()
        }
    }

    /// Sends out one creature, and sometimes a second a moment behind it.
    private func sendOut() {
        let first = makeCritter(after: 0)
        var group = [first]
        if Double.random(in: 0...1) < 0.3 {
            group.append(makeCritter(after: 0.7, goingRight: first.goesRight))
        }
        // Never more than a few on screen at once.
        critters = Array((critters + group).suffix(4))

        for critter in group {
            Task {
                try? await Task.sleep(for: .seconds(critter.kind.duration + 1.5))
                critters.removeAll { $0.id == critter.id }
            }
        }
    }

    private func makeCritter(after delay: Double, goingRight: Bool = Bool.random()) -> Critter {
        // A different creature each time, rather than the same one twice running.
        let options = CritterKind.allCases.filter { $0 != lastKind }
        let kind = options.randomElement() ?? .hare
        lastKind = kind
        return Critter(
            kind: kind,
            goesRight: goingRight,
            start: Date.now.addingTimeInterval(delay),
            lane: Double.random(in: 0...1)
        )
    }
}

/// Draws one creature and moves it along its path over time.
struct CritterView: View {
    let critter: Critter
    let banner: CGSize
    /// The silhouette's color. The default is a faint shadow; scenes with a light ground use something darker.
    var color: Color = .black.opacity(0.22)

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(critter.start)
            let progress = min(max(elapsed / critter.kind.duration, 0), 1)
            let pose = Pose(kind: critter.kind, progress: progress, lane: critter.lane, banner: banner)

            CritterArt(kind: critter.kind, phase: pose.phase, color: color)
                .scaleEffect(x: critter.goesRight == critter.kind.facesRight ? 1 : -1, y: 1)
                .rotationEffect(.degrees(pose.tilt))
                .position(
                    x: critter.goesRight ? pose.x : banner.width - pose.x,
                    y: pose.y
                )
                // Hidden until it's started, and again once it's off the far edge.
                .opacity(elapsed > 0 && progress < 1 ? 1 : 0)
        }
    }
}

/// Where a creature is, and how it's moving, at a moment in its crossing.
private struct Pose {
    let x: CGFloat
    let y: CGFloat
    let tilt: Double
    /// A repeating -1...1 value driving flaps and similar motion.
    let phase: Double

    init(kind: CritterKind, progress t: Double, lane: Double, banner: CGSize) {
        let size = kind.size
        let margin = size * 1.5
        let travel = banner.width + margin * 2

        // Lizards dash and pause; everything else keeps a steady pace.
        let eased = kind == .lizard ? t - sin(t * 2 * .pi * 4) / (2 * .pi * 4) * 0.7 : t
        x = -margin + travel * eased

        // Walkers keep to the bottom of the banner, in one of two lanes; flyers stay high up.
        let ground = banner.height - size * 0.5 - 10 - lane * 6
        let sky = banner.height * (0.22 + 0.18 * lane)

        switch kind {
        case .hare:
            let hop = abs(sin(t * .pi * 7))
            y = ground - hop * size * 0.6
            tilt = -cos(t * .pi * 7) * 10
            phase = sin(t * .pi * 7)
        case .bird:
            y = sky + sin(t * .pi * 3) * 10
            tilt = cos(t * .pi * 3) * 7
            phase = sin(t * .pi * 16)
        case .owl:
            y = sky + sin(t * .pi * 2.5) * 12
            tilt = cos(t * .pi * 2.5) * 5
            phase = sin(t * .pi * 9)
        case .tortoise:
            y = ground + sin(t * .pi * 12) * 1.2
            tilt = sin(t * .pi * 12) * 2
            phase = sin(t * .pi * 12)
        case .lizard:
            y = ground + sin(t * .pi * 22) * 1.5
            tilt = sin(t * .pi * 22) * 4
            phase = sin(t * .pi * 22)
        case .ladybug:
            y = ground + 6 + sin(t * .pi * 16) * 1
            tilt = sin(t * .pi * 16) * 3
            phase = sin(t * .pi * 16)
        case .hedgehog:
            y = ground + sin(t * .pi * 20) * 1.5
            tilt = sin(t * .pi * 10) * 5
            phase = sin(t * .pi * 10)
        case .fox:
            y = ground - abs(sin(t * .pi * 9)) * 5
            tilt = sin(t * .pi * 9) * 2.5
            phase = sin(t * .pi * 9)
        }
    }
}

/// A creature's silhouette, in a translucent dark shadow of whatever the banner's color is.
struct CritterArt: View {
    let kind: CritterKind
    /// -1...1, repeating, for wing flaps and the like.
    var phase: Double = 0
    var color: Color = .black.opacity(0.22)

    var body: some View {
        art
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var art: some View {
        switch kind {
        case .hare:
            symbol("hare.fill")
        case .bird:
            symbol("bird.fill")
                // A quick squash and stretch reads as flapping.
                .scaleEffect(x: 1, y: 1 - 0.18 * abs(phase))
        case .tortoise:
            symbol("tortoise.fill")
        case .lizard:
            // The symbol points up, so it's turned to point along its path.
            symbol("lizard.fill")
                .rotationEffect(.degrees(75))
        case .ladybug:
            symbol("ladybug.fill")
        case .hedgehog:
            HedgehogShape()
                .frame(width: kind.size, height: kind.size * 0.7)
        case .fox:
            FoxShape()
                .frame(width: kind.size, height: kind.size * 0.62)
        case .owl:
            OwlSilhouette(side: kind.size, flap: phase)
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: kind.size))
    }
}

/// A hedgehog in profile, facing right: a dome of spines with a pointed snout.
struct HedgehogShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        let centerX = 0.42, centerY = 0.80
        let radiusX = 0.40, radiusY = 0.72
        let spines = 13

        // The back, from the left end over the top to the right end, as alternating spine tips and valleys.
        path.move(to: point(centerX - radiusX, centerY))
        for index in 0..<spines {
            let tip = Double.pi - Double.pi * (Double(index) + 0.5) / Double(spines)
            let valley = Double.pi - Double.pi * Double(index + 1) / Double(spines)
            path.addLine(to: point(
                centerX + cos(tip) * radiusX * 1.14,
                centerY - sin(tip) * radiusY * 1.14
            ))
            path.addLine(to: point(
                centerX + cos(valley) * radiusX,
                centerY - sin(valley) * radiusY
            ))
        }

        // Face and snout, then back along the belly, with two little feet.
        path.addLine(to: point(0.98, 0.88))
        path.addLine(to: point(0.80, 0.95))
        path.addLine(to: point(0.72, 0.95))
        path.addLine(to: point(0.72, 1.0))
        path.addLine(to: point(0.58, 1.0))
        path.addLine(to: point(0.58, 0.95))
        path.addLine(to: point(0.26, 0.95))
        path.addLine(to: point(0.26, 1.0))
        path.addLine(to: point(0.12, 1.0))
        path.addLine(to: point(0.12, 0.95))
        path.addLine(to: point(centerX - radiusX, centerY))
        path.closeSubpath()
        return path
    }
}

/// A fox trotting right: pointed ears and snout, four legs, and a big sweeping tail.
struct FoxShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        func oval(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CGRect {
            CGRect(
                x: rect.minX + rect.width * x,
                y: rect.minY + rect.height * y,
                width: rect.width * width,
                height: rect.height * height
            )
        }

        var path = Path()

        // Body and head.
        path.addEllipse(in: oval(0.20, 0.40, 0.52, 0.34))
        path.addEllipse(in: oval(0.64, 0.20, 0.24, 0.30))

        // Snout.
        path.move(to: point(0.84, 0.30))
        path.addLine(to: point(1.0, 0.42))
        path.addLine(to: point(0.82, 0.48))
        path.closeSubpath()

        // Ears.
        path.move(to: point(0.67, 0.28))
        path.addLine(to: point(0.69, 0.0))
        path.addLine(to: point(0.79, 0.22))
        path.closeSubpath()
        path.move(to: point(0.76, 0.22))
        path.addLine(to: point(0.85, 0.0))
        path.addLine(to: point(0.88, 0.30))
        path.closeSubpath()

        // Legs.
        for x in [0.27, 0.37, 0.57, 0.67] {
            path.addRoundedRect(in: oval(x, 0.64, 0.05, 0.36), cornerSize: CGSize(width: 2, height: 2))
        }

        // Tail, curving up and back from the rump.
        path.move(to: point(0.26, 0.50))
        path.addQuadCurve(to: point(0.0, 0.16), control: point(0.0, 0.50))
        path.addQuadCurve(to: point(0.28, 0.66), control: point(0.30, 0.10))
        path.closeSubpath()

        return path
    }
}

/// An owl in flight, seen from the front, with ear tufts, round eyes, and wings that flap with `flap`.
struct OwlSilhouette: View {
    let side: CGFloat
    /// -1...1, driving the wings.
    let flap: Double

    var body: some View {
        ZStack {
            OwlBodyShape()
                .frame(width: side, height: side)

            // Wings, hinged at the shoulders.
            Capsule()
                .frame(width: side * 0.44, height: side * 0.21)
                .rotationEffect(.degrees(-20 - flap * 32), anchor: .trailing)
                .offset(x: -side * 0.37, y: side * 0.08)
            Capsule()
                .frame(width: side * 0.44, height: side * 0.21)
                .rotationEffect(.degrees(20 + flap * 32), anchor: .leading)
                .offset(x: side * 0.37, y: side * 0.08)

            // Eyes are cut out of the shadow.
            HStack(spacing: side * 0.10) {
                Circle().frame(width: side * 0.15, height: side * 0.15)
                Circle().frame(width: side * 0.15, height: side * 0.15)
            }
            .offset(y: -side * 0.14)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
        .frame(width: side * 1.5, height: side)
    }
}

private struct OwlBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        // Body and round head.
        path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.30,
                                   width: rect.width * 0.48, height: rect.height * 0.66))
        path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.10,
                                   width: rect.width * 0.44, height: rect.height * 0.40))
        // Ear tufts.
        path.move(to: point(0.30, 0.22))
        path.addLine(to: point(0.29, 0.0))
        path.addLine(to: point(0.43, 0.14))
        path.closeSubpath()
        path.move(to: point(0.70, 0.22))
        path.addLine(to: point(0.71, 0.0))
        path.addLine(to: point(0.57, 0.14))
        path.closeSubpath()
        return path
    }
}

#Preview("Mid-run on a banner") {
    // Creatures started a little while ago, so they're partway across.
    let samples: [(CritterKind, Bool, TimeInterval, Double)] = [
        (.hare, true, 1.3, 0.2),
        (.fox, false, 0.9, 0.9),
        (.owl, true, 1.2, 0.4),
        (.hedgehog, true, 1.6, 0.0),
        (.ladybug, false, 1.0, 0.6),
        (.bird, false, 1.1, 0.9)
    ]
    return VStack(spacing: 0) {
        Color.clear
            .frame(height: 150)
            .background(alignment: .bottom) {
                BannerBackground(color: BannerPalette.collection)
            }
            .overlay {
                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<samples.count, id: \.self) { index in
                            let sample = samples[index]
                            CritterView(
                                critter: Critter(
                                    kind: sample.0,
                                    goesRight: sample.1,
                                    start: Date.now.addingTimeInterval(-sample.2),
                                    lane: sample.3
                                ),
                                banner: geometry.size
                            )
                        }
                    }
                }
            }
        Spacer()
    }
}

#Preview("Critters") {
    let columns = [GridItem(.adaptive(minimum: 90))]
    return LazyVGrid(columns: columns, spacing: 24) {
        ForEach(CritterKind.allCases, id: \.self) { kind in
            VStack(spacing: 6) {
                CritterArt(kind: kind, phase: 0.5)
                    .frame(height: 70)
                Text(String(describing: kind))
                    .font(.caption)
            }
        }
    }
    .padding(24)
    .background(BannerPalette.collection)
    .foregroundStyle(.white)
}
