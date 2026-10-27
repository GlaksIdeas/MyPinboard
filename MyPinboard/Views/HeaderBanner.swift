import SwiftUI

/// Solid colors for header banners. Each is dark enough for white text.
enum BannerPalette {
    /// The Collection's banner: a deep teal that sets off the app's orange accent.
    static let collection = Color(red: 0.11, green: 0.42, blue: 0.46)

    private static let profileColors: [Color] = [
        Color(red: 0.80, green: 0.36, blue: 0.24), // terracotta
        Color(red: 0.13, green: 0.47, blue: 0.50), // teal
        Color(red: 0.45, green: 0.26, blue: 0.54), // plum
        Color(red: 0.25, green: 0.33, blue: 0.64), // indigo
        Color(red: 0.20, green: 0.46, blue: 0.33), // forest
        Color(red: 0.76, green: 0.29, blue: 0.45)  // rose
    ]

    /// A profile's color, fixed by its ID so everyone sees the same color for the same person.
    static func color(for id: UUID) -> Color {
        let sum = id.uuidString.utf8.reduce(0) { $0 &+ Int($1) }
        return profileColors[sum % profileColors.count]
    }
}

/// The colored shape behind a banner. It reaches far above its frame, so the color fills the status
/// bar area and still covers the top when the screen is pulled down past its start.
struct BannerBackground: View {
    let color: Color

    var body: some View {
        UnevenRoundedRectangle(
            bottomLeadingRadius: 32,
            bottomTrailingRadius: 32,
            style: .continuous
        )
        .fill(color)
        .padding(.top, -1500)
    }
}

/// A banner's colored surface, with the shadow creatures that scurry across it when the page is tugged.
struct BannerSurface: View {
    let color: Color

    var body: some View {
        ZStack {
            BannerBackground(color: color)
            BannerCritters()
        }
    }
}

/// A solid banner with a big title at the top of a scrolling screen. It's part of the scrolled content,
/// so it moves up and away as you scroll; pair it with `collapsingBannerTitle` to show the title in the bar.
struct HeaderBanner: View {
    let title: String
    var subtitle: String?
    let color: Color
    var height: CGFloat = 130

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .bottomLeading)
        .background(alignment: .bottom) {
            BannerSurface(color: color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Shows `title` in the navigation bar only once the content has scrolled up past the banner, so the
    /// title doesn't appear twice while the banner is on screen.
    func collapsingBannerTitle(_ title: String, bannerHeight: CGFloat = 110) -> some View {
        modifier(CollapsingBannerTitle(title: title, threshold: bannerHeight))
    }
}

private struct CollapsingBannerTitle: ViewModifier {
    let title: String
    let threshold: CGFloat

    @State private var isCollapsed = false
    /// Goes up each time the page is pulled down past its top; banners send out a creature on every change.
    @State private var tugCount = 0

    /// How far past the top, in points, the page has to be pulled to count as a tug.
    private let tugDistance: CGFloat = 70

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > threshold
            } action: { _, collapsed in
                isCollapsed = collapsed
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top < -tugDistance
            } action: { wasPulled, isPulled in
                if isPulled && !wasPulled {
                    tugCount += 1
                }
            }
            .environment(\.bannerTug, tugCount)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: tugCount)
            .navigationTitle(isCollapsed ? title : "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }
}
