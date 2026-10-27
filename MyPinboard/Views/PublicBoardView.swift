import SwiftUI
import SwiftData

/// A read-only board on its wall, from a snapshot. Tap a pin to report it through `onSelectPin`.
/// This is the content on its own; `PublicBoardView` and `BoardPagerView` add titles and toolbars around it.
struct PublicBoardCanvas: View {
    let board: BoardSnapshot
    /// Whether to draw the board's wall behind it. A viewer that draws one wall behind many boards turns this off.
    var showsWall = true
    /// Extra room below the board, for something like page dots.
    var bottomInset: CGFloat = 0
    let onSelectPin: (PinSnapshot) -> Void

    var body: some View {
        BoardCanvas(
            appearance: board.appearance,
            isEmpty: board.pins.isEmpty,
            emptyMessage: "Nothing is pinned here yet.",
            contentInsets: EdgeInsets(top: 8, leading: 16, bottom: 8 + bottomInset, trailing: 16)
        ) { size in
            ForEach(board.pins) { pin in
                StaticPinView(pin: pin, boardSize: size)
                    .onTapGesture { onSelectPin(pin) }
            }
        } overlay: {
        }
        .background {
            if showsWall {
                BoardWall(style: board.appearance.wall, customData: board.appearance.customWallData)
                    .ignoresSafeArea()
            }
        }
    }
}

/// A read-only view of one board, with a title and a Share button. Works the same for your own
/// boards and for friends' boards.
struct PublicBoardView: View {
    let board: BoardSnapshot
    /// Shown in the shared image, e.g. "@sam".
    var credit: String?

    @State private var selectedPin: PinSnapshot?

    var body: some View {
        PublicBoardCanvas(board: board) { selectedPin = $0 }
            .navigationTitle(board.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: BoardImage(board: board, credit: credit),
                        preview: SharePreview(board.name)
                    ) {
                        Label("Share Board", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .pinDetailSheet(pin: $selectedPin, boardName: board.name)
    }
}

/// A full-screen viewer for a set of boards: swipe left and right to move between them, tap a pin for
/// its details. Used when a board is tapped on a profile.
struct BoardPagerView: View {
    let boards: [BoardSnapshot]
    @Binding var selection: UUID
    var credit: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPin: PinSnapshot?

    private var current: BoardSnapshot? {
        boards.first { $0.id == selection } ?? boards.first
    }

    var body: some View {
        NavigationStack {
            pager
                .navigationTitle(current?.name ?? "Board")
                .navigationSubtitle(position)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                    if let current {
                        ToolbarItem(placement: .primaryAction) {
                            ShareLink(
                                item: BoardImage(board: current, credit: credit),
                                preview: SharePreview(current.name)
                            ) {
                                Label("Share Board", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
                .pinDetailSheet(pin: $selectedPin, boardName: current?.name)
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 680)
        #endif
    }

    /// "2 of 3", or nothing when there's only one board.
    private var position: String {
        guard boards.count > 1, let index = boards.firstIndex(where: { $0.id == selection }) else { return "" }
        return "\(index + 1) of \(boards.count)"
    }

    @ViewBuilder
    private var pager: some View {
        #if os(iOS)
        TabView(selection: $selection) {
            ForEach(boards) { board in
                // Leaves room for the page dots under the board.
                PublicBoardCanvas(board: board, showsWall: false, bottomInset: boards.count > 1 ? 28 : 0) {
                    selectedPin = $0
                }
                .tag(board.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: boards.count > 1 ? .always : .never))
        // One wall behind all the pages: a paged view clips each page's own background to the page,
        // which would leave bars of plain color at the top and bottom.
        .background {
            if let current {
                BoardWall(style: current.appearance.wall, customData: current.appearance.customWallData)
                    .ignoresSafeArea()
                    .id(current.id)
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: selection)
        #else
        // No swipe paging on the Mac, so previous and next buttons step through the boards instead.
        if let current {
            PublicBoardCanvas(board: current) { selectedPin = $0 }
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Button("Previous Board", systemImage: "chevron.left") { step(-1) }
                            .disabled(boards.count < 2)
                        Button("Next Board", systemImage: "chevron.right") { step(1) }
                            .disabled(boards.count < 2)
                    }
                }
        }
        #endif
    }

    #if os(macOS)
    private func step(_ offset: Int) {
        guard let index = boards.firstIndex(where: { $0.id == selection }), !boards.isEmpty else { return }
        let next = (index + offset + boards.count) % boards.count
        selection = boards[next].id
    }
    #endif
}

#Preview("Board viewer") {
    PreviewBoardPager()
        .modelContainer(previewContainer())
}

/// Opens the viewer on the sample boards.
private struct PreviewBoardPager: View {
    @Query(sort: \Board.dateCreated) private var boards: [Board]
    @State private var page = UUID()

    var body: some View {
        let snapshots = boards.map(BoardSnapshot.init)
        BoardPagerView(boards: snapshots, selection: $page, credit: "@sam.pins")
            .task {
                if let first = snapshots.first {
                    page = first.id
                }
            }
    }
}

private extension View {
    /// Presents a read-only pin's details in a sheet.
    func pinDetailSheet(pin: Binding<PinSnapshot?>, boardName: String?) -> some View {
        sheet(item: pin) { snapshot in
            NavigationStack {
                PinDetailContent(snapshot: snapshot, boardName: boardName)
                    .navigationTitle(snapshot.name)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { pin.wrappedValue = nil }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 560)
            #endif
        }
    }
}

/// A pin as it sits on a board you can't edit. Sized and placed relative to the board, so it matches
/// the editable board at any size.
struct StaticPinView: View {
    let pin: PinSnapshot
    let boardSize: CGSize

    @Environment(\.boardEdgeInset) private var edgeInset
    @Environment(\.boardLightingPaused) private var isStatic

    /// A visitor can open and close a book pin for themselves; this overrides how its owner left it.
    @State private var openOverride: Bool?

    private var isOpen: Bool {
        pin.canOpen && (openOverride ?? pin.isOpen ?? false)
    }

    var body: some View {
        let baseSize = BoardMetrics.pinBaseSize(in: boardSize)

        PinArt(
            imageData: pin.imageData,
            openImageData: pin.openImageData,
            opensLikeBook: pin.opensLikeBook ?? false,
            isOpen: isOpen,
            isShimmery: pin.isShimmery ?? false,
            seed: pin.id,
            side: baseSize
        )
            .overlay(alignment: .topTrailing) {
                // A small book button, except on thumbnails and exported pictures where it can't be tapped.
                if pin.canOpen && !isStatic {
                    Button {
                        openOverride = !isOpen
                    } label: {
                        Image(systemName: isOpen ? "book.closed.fill" : "book.fill")
                            .font(.system(size: max(baseSize * 0.16, 9)))
                            .padding(max(baseSize * 0.07, 4))
                            .background(.regularMaterial, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isOpen ? "Close \(pin.name)" : "Open \(pin.name)")
                }
            }
            .scaleEffect(pin.scale)
            .rotationEffect(.degrees(pin.rotation))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .position(
                BoardMetrics.pinCenter(
                    x: pin.positionX,
                    y: pin.positionY,
                    scale: pin.scale * (isOpen ? 2 : 1),
                    in: boardSize,
                    inset: edgeInset
                )
            )
            .accessibilityLabel(pin.name)
            .accessibilityAddTraits(.isButton)
    }
}
