import SwiftUI
import SwiftData

/// How large a pin can be made on a board, as a multiple of its base size.
private let pinScaleRange: ClosedRange<Double> = 0.4...3.0

/// A free-form board, shown as a floating rounded card, where pins can be dragged around, resized, and rotated.
///
/// Tap or start dragging a pin to select it. A selected pin can then be moved, pinched, and twisted
/// from anywhere on the board, not just with fingers on the pin.
struct BoardView: View {
    @Bindable var board: Board

    @State private var selectedPinID: PersistentIdentifier?
    /// Where the selected pin was when a drag anywhere on the board began.
    @State private var moveOrigin: CGPoint?
    /// Live multiplier from an in-progress pinch, applied to the selected pin until the pinch ends.
    @State private var pinchScale: Double = 1
    /// Live rotation from an in-progress twist, applied to the selected pin until the twist ends.
    @State private var twist: Angle = .zero

    private let insets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

    private var pins: [Pin] {
        (board.pins ?? []).sorted { $0.dateAdded < $1.dateAdded }
    }

    private var selectedPin: Pin? {
        pins.first { $0.persistentModelID == selectedPinID }
    }

    var body: some View {
        GeometryReader { screen in
            let boardSize = CGSize(
                width: max(screen.size.width - insets.leading - insets.trailing, 1),
                height: max(screen.size.height - insets.top - insets.bottom, 1)
            )

            BoardCanvas(
                appearance: board.appearance,
                isEmpty: pins.isEmpty,
                contentInsets: insets,
                onBackgroundTap: { selectedPinID = nil }
            ) { size in
                ForEach(pins) { pin in
                    let isSelected = pin.persistentModelID == selectedPinID
                    BoardPinView(
                        pin: pin,
                        boardSize: size,
                        isSelected: isSelected,
                        liveScale: isSelected ? pinchScale : 1,
                        liveTwist: isSelected ? twist : .zero,
                        onSelect: { selectedPinID = pin.persistentModelID }
                    )
                    .zIndex(isSelected ? 1 : 0)
                }
            } overlay: {
                if let selectedPin {
                    PinControlsPanel(pin: selectedPin) { selectedPinID = nil }
                        .padding(.horizontal, BoardMetrics.frameWidth + 8)
                        .padding(.bottom, BoardMetrics.frameWidth + 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // The whole area, including the margin around the board, accepts input for the selected pin.
            .contentShape(Rectangle())
            // A plain gesture, so a pin touched directly handles its own drag and this only applies elsewhere.
            .gesture(moveGesture(in: boardSize))
            .simultaneousGesture(pinchGesture)
            .simultaneousGesture(twistGesture)
        }
        .animation(.smooth, value: selectedPinID)
    }

    /// Moves the selected pin by however far a finger travels, wherever on the board it started.
    private func moveGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard let pin = selectedPin else { return }
                if moveOrigin == nil {
                    moveOrigin = CGPoint(x: pin.positionX, y: pin.positionY)
                }
                guard let origin = moveOrigin else { return }
                pin.positionX = min(max(origin.x + value.translation.width / size.width, 0), 1)
                pin.positionY = min(max(origin.y + value.translation.height / size.height, 0), 1)
            }
            .onEnded { _ in
                moveOrigin = nil
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard selectedPin != nil else { return }
                pinchScale = value.magnification
            }
            .onEnded { value in
                if let pin = selectedPin {
                    pin.scale = clampedScale(pin.scale * value.magnification)
                }
                pinchScale = 1
            }
    }

    private var twistGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                guard selectedPin != nil else { return }
                twist = value.rotation
            }
            .onEnded { value in
                if let pin = selectedPin {
                    pin.rotation = normalizedRotation(pin.rotation + value.rotation.degrees)
                }
                twist = .zero
            }
    }
}

private func clampedScale(_ scale: Double) -> Double {
    min(max(scale, pinScaleRange.lowerBound), pinScaleRange.upperBound)
}

/// Wraps any angle in degrees into -180...180, so the rotation slider always has a position.
private func normalizedRotation(_ degrees: Double) -> Double {
    let wrapped = (degrees + 180).truncatingRemainder(dividingBy: 360)
    return (wrapped < 0 ? wrapped + 360 : wrapped) - 180
}

private struct BoardPinView: View {
    @Bindable var pin: Pin
    let boardSize: CGSize
    let isSelected: Bool
    /// In-progress pinch and twist, handled for the whole board and passed in for the selected pin.
    let liveScale: Double
    let liveTwist: Angle
    let onSelect: () -> Void

    @Environment(\.boardEdgeInset) private var edgeInset
    @State private var isDragging = false

    var body: some View {
        let baseSize = BoardMetrics.pinBaseSize(in: boardSize)
        let scale = clampedScale(pin.scale * liveScale)
        let isShowingOpen = pin.canOpen && pin.isOpen

        PinArt(
            imageData: pin.imageData,
            openImageData: pin.openImageData,
            opensLikeBook: pin.opensLikeBook,
            isOpen: pin.isOpen,
            isShimmery: pin.isShimmery,
            seed: pin.uuid,
            side: baseSize
        )
            .overlay {
                if isSelected {
                    // Outlines the whole pin, which is twice as wide when it's open.
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .frame(width: isShowingOpen ? baseSize * 2 : baseSize, height: baseSize)
                        .animation(.smooth, value: isShowingOpen)
                }
            }
            .scaleEffect(scale * (isDragging ? 1.12 : 1))
            .rotationEffect(.degrees(pin.rotation) + liveTwist)
            // The pin lifts off the surface while it's held.
            .shadow(
                color: .black.opacity(isDragging ? 0.4 : 0.25),
                radius: isDragging ? 10 : 3,
                y: isDragging ? 8 : 2
            )
            .animation(.spring(duration: 0.25), value: isDragging)
            .position(
                BoardMetrics.pinCenter(
                    x: pin.positionX,
                    y: pin.positionY,
                    // An open book pin is twice as wide, so it keeps further from the edges.
                    scale: scale * (isShowingOpen ? 2 : 1),
                    in: boardSize,
                    inset: edgeInset
                )
            )
            .onTapGesture(perform: onSelect)
            // Double-tap a book pin to open or close it.
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    if pin.canOpen {
                        pin.isOpen.toggle()
                    }
                }
            )
            .gesture(
                DragGesture(coordinateSpace: .named("board"))
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onSelect()
                        }
                        guard boardSize.width > 0, boardSize.height > 0 else { return }
                        pin.positionX = min(max(value.location.x / boardSize.width, 0), 1)
                        pin.positionY = min(max(value.location.y / boardSize.height, 0), 1)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: isDragging)
            .accessibilityLabel(pin.name)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The glass bar for fine-tuning the selected pin's size and angle. It slides away when the pin is deselected.
private struct PinControlsPanel: View {
    @Bindable var pin: Pin
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    Slider(value: $pin.scale, in: pinScaleRange)
                        .accessibilityLabel("Size of \(pin.name)")
                }

                HStack(spacing: 10) {
                    Image(systemName: "rotate.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    Slider(
                        value: Binding(
                            get: { normalizedRotation(pin.rotation) },
                            set: { pin.rotation = $0 }
                        ),
                        in: -180...180
                    )
                    .accessibilityLabel("Rotation of \(pin.name)")
                }
            }

            VStack(spacing: 8) {
                // Only pins that open get an Open button.
                if pin.canOpen {
                    Button {
                        pin.isOpen.toggle()
                    } label: {
                        Label(pin.isOpen ? "Close" : "Open", systemImage: pin.isOpen ? "book.closed" : "book")
                    }
                    .buttonStyle(.glass)
                    .sensoryFeedback(.impact(weight: .light), trigger: pin.isOpen)
                }

                Button("Done") { onDone() }
                    .buttonStyle(.glass)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}

#Preview("Controls panel") {
    let pin = Pin(name: "Sunset Fox")
    pin.scale = 1.4
    pin.rotation = 12
    return ZStack {
        BoardBackground(style: .cork)
        PinControlsPanel(pin: pin) {}
            .padding(24)
    }
}
