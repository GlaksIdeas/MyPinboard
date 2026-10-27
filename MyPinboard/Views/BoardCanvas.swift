import SwiftUI

extension EnvironmentValues {
    /// How far in from the board's edge pins must stay, set by the board that holds them.
    @Entry var boardEdgeInset: CGFloat = 0
}

/// Draws a board: surface, shadowbox frame, lights, and halo, with the pins supplied by the caller.
/// Used for both the editable board and read-only views of someone's board, so they always look identical.
struct BoardCanvas<Pins: View, Overlay: View>: View {
    let appearance: BoardAppearance
    let isEmpty: Bool
    var emptyMessage = "Add a pin to start your board."
    var contentInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    /// Called when the bare surface is tapped.
    var onBackgroundTap: (() -> Void)?
    /// The pins, given the board's size so they can position themselves.
    @ViewBuilder let pins: (CGSize) -> Pins
    /// Anything floating above the board, aligned to its bottom edge.
    @ViewBuilder let overlay: () -> Overlay

    private let shape = RoundedRectangle(cornerRadius: BoardMetrics.cornerRadius, style: .continuous)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BoardBackground(style: appearance.style, customData: appearance.customBoardData)

                if appearance.showShadowbox {
                    ShadowboxDepth()
                }

                lightingGlow

                // Tapping the bare surface reaches the caller; pins sit above and take their own taps.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onBackgroundTap?() }

                if isEmpty {
                    ContentUnavailableView(
                        "No Pins Yet",
                        systemImage: "pin",
                        description: Text(emptyMessage)
                    )
                    .padding(24)
                    .glassEffect(in: .rect(cornerRadius: 28))
                    .padding(32)
                }

                // Pins get their own stack so a selected pin rises above the others
                // without ending up on top of the frame.
                ZStack {
                    pins(geometry.size)
                }
                .environment(\.boardEdgeInset, BoardMetrics.pinEdgeInset(showShadowbox: appearance.showShadowbox))

                if appearance.showShadowbox {
                    ShadowboxFrame()
                }

                if appearance.lighting == .ledStrip {
                    // Sit the bulbs on the middle of the frame when there is one.
                    BoardLEDStrip(
                        color: appearance.lightColor,
                        inset: appearance.showShadowbox ? BoardMetrics.frameWidth / 2 : 8
                    )
                }
            }
            .coordinateSpace(.named("board"))
            .overlay(alignment: .bottom) {
                overlay()
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.28), radius: 20, y: 12)
            .background { halo }
        }
        .padding(contentInsets)
    }

    /// Light on the surface, inside the board.
    @ViewBuilder
    private var lightingGlow: some View {
        switch appearance.lighting {
        case .off:
            EmptyView()
        case .ambientGlow:
            BoardGlow(color: appearance.lightColor, strength: 0.8)
        case .ledStrip:
            // Faint spill from the bulbs onto the surface.
            BoardGlow(color: appearance.lightColor, strength: 0.35)
        }
    }

    /// Light spilling out past the board's edge.
    @ViewBuilder
    private var halo: some View {
        switch appearance.lighting {
        case .off:
            EmptyView()
        case .ambientGlow:
            BoardHalo(color: appearance.lightColor, strength: 0.75)
        case .ledStrip:
            BoardHalo(color: appearance.lightColor, strength: 0.4)
        }
    }
}
