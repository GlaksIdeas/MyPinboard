import SwiftUI
import SwiftData

/// Hosts the selected board and lets you switch between, create, and customize boards.
/// Expects to be placed inside a NavigationStack.
struct BoardsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Board.dateCreated) private var boards: [Board]

    @AppStorage("selectedBoardID") private var selectedBoardID = ""
    @AppStorage("didMigrateToBoards") private var didMigrateToBoards = false

    @Query private var profiles: [Profile]

    /// A read-only copy of the board, shown the way friends see it, with a Share button.
    @State private var previewSnapshot: BoardSnapshot?
    @State private var isWaitingForSync = false
    @State private var settingsBoard: Board?
    /// Deleted once the settings sheet has finished dismissing, so the sheet never shows a deleted board.
    @State private var boardPendingDeletion: Board?

    private var selectedBoard: Board? {
        boards.first { $0.uuid.uuidString == selectedBoardID } ?? boards.first
    }

    var body: some View {
        Group {
            if let board = selectedBoard {
                BoardView(board: board)
            } else if isWaitingForSync {
                ProgressView("Checking iCloud…")
            } else {
                ProgressView()
            }
        }
        .background {
            BoardWall(style: selectedBoard?.wall ?? .plaster, customData: selectedBoard?.customWallData)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BoardChipBar(
                boards: boards,
                selectedID: selectedBoard?.uuid,
                onSelect: { selectedBoardID = $0.uuid.uuidString },
                onEdit: { settingsBoard = $0 },
                onAdd: createBoard
            )
            .padding(.vertical, 6)
        }
        .navigationTitle("Boards")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Board Settings", systemImage: "slider.horizontal.3") {
                    settingsBoard = selectedBoard
                }
                .disabled(selectedBoard == nil)
            }

            ToolbarItem(placement: .secondaryAction) {
                Button("Preview & Share", systemImage: "square.and.arrow.up") {
                    if let board = selectedBoard {
                        previewSnapshot = BoardSnapshot(board)
                    }
                }
                .disabled(selectedBoard == nil)
            }
        }
        .sheet(item: $previewSnapshot) { snapshot in
            NavigationStack {
                PublicBoardView(
                    board: snapshot,
                    credit: profiles.first.flatMap { $0.handle.isEmpty ? nil : "@\($0.handle)" }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { previewSnapshot = nil }
                    }
                }
            }
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 640)
            #endif
        }
        .sheet(item: $settingsBoard, onDismiss: deletePendingBoard) { board in
            BoardSettingsView(board: board, canDelete: boards.count > 1) {
                boardPendingDeletion = board
            }
        }
        .task { await bootstrap() }
    }

    private func createBoard() {
        let board = Board(name: "Board \(boards.count + 1)")
        modelContext.insert(board)
        selectedBoardID = board.uuid.uuidString
        // Open settings right away so the new board can be named and styled.
        settingsBoard = board
    }

    private func deletePendingBoard() {
        guard let doomed = boardPendingDeletion else { return }
        boardPendingDeletion = nil
        if let replacement = boards.first(where: { $0.uuid != doomed.uuid }) {
            selectedBoardID = replacement.uuid.uuidString
        }
        modelContext.delete(doomed)
    }

    private func boardCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<Board>())) ?? 0
    }

    /// Makes sure at least one board exists.
    ///
    /// A fresh install on an iCloud account may be about to receive boards from the person's other
    /// devices, so it waits a few seconds for them rather than creating a duplicate "My Board".
    private func bootstrap() async {
        guard boardCount() == 0 else {
            didMigrateToBoards = true
            return
        }

        let hasLocalPins = ((try? modelContext.fetchCount(FetchDescriptor<Pin>())) ?? 0) > 0
        if !hasLocalPins, FileManager.default.ubiquityIdentityToken != nil {
            isWaitingForSync = true
            defer { isWaitingForSync = false }
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(500))
                if Task.isCancelled { return }
                if boardCount() > 0 {
                    didMigrateToBoards = true
                    return
                }
            }
        }

        createDefaultBoard()
    }

    /// Creates the first board. Pins that predate boards are moved onto it, and the previous
    /// single-board look is carried over.
    private func createDefaultBoard() {
        let board = Board(name: "My Board")
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "boardStyle"), let style = BoardStyle(rawValue: raw) {
            board.style = style
        }
        if defaults.object(forKey: "boardShadowbox") != nil {
            board.showShadowbox = defaults.bool(forKey: "boardShadowbox")
        }
        modelContext.insert(board)

        if !didMigrateToBoards {
            let unplaced = (try? modelContext.fetch(
                FetchDescriptor<Pin>(predicate: #Predicate { $0.board == nil })
            )) ?? []
            for pin in unplaced {
                pin.board = board
            }
        }

        didMigrateToBoards = true
        selectedBoardID = board.uuid.uuidString
    }
}

/// A scrolling row of glass capsules, one per board, plus a button to add another.
private struct BoardChipBar: View {
    let boards: [Board]
    let selectedID: UUID?
    let onSelect: (Board) -> Void
    let onEdit: (Board) -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(boards) { board in
                        chip(for: board)
                    }

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("New Board")
                }
                .padding(.horizontal, 16)
            }
        }
        .scrollClipDisabled()
        // A horizontal ScrollView otherwise stretches to fill the height it's offered.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chip(for board: Board) -> some View {
        let isSelected = board.uuid == selectedID
        return Button {
            onSelect(board)
        } label: {
            Text(board.name.isEmpty ? "Untitled Board" : board.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 16)
                .frame(height: 36)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
            in: .capsule
        )
        .contextMenu {
            Button("Board Settings", systemImage: "slider.horizontal.3") {
                onEdit(board)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
