import SwiftUI
import SwiftData

/// Sheet for renaming a board and changing its surface, frame, and lighting.
struct BoardSettingsView: View {
    @Bindable var board: Board
    let canDelete: Bool
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Board Name", text: $board.name)
                }

                Section("Board Surface") {
                    Picker("Surface", selection: $board.style) {
                        ForEach(BoardStyle.presets) { style in
                            Text(style.title).tag(style)
                        }
                        if board.customBoardData != nil {
                            Text(BoardStyle.custom.title).tag(BoardStyle.custom)
                        }
                    }
                    CustomPhotoRow(
                        title: "Use Your Own Photo",
                        data: $board.customBoardData,
                        onChosen: { board.style = .custom },
                        onRemoved: { if board.style == .custom { board.style = .cork } }
                    )
                    Toggle("Shadowbox Frame", isOn: $board.showShadowbox)
                }

                Section("Wall") {
                    WallPicker(selection: $board.wall, customData: board.customWallData)
                    CustomPhotoRow(
                        title: "Use Your Own Photo",
                        data: $board.customWallData,
                        onChosen: { board.wall = .custom },
                        onRemoved: { if board.wall == .custom { board.wall = .plaster } }
                    )
                }

                Section("Lighting") {
                    Picker("Lighting", selection: $board.lighting) {
                        ForEach(BoardLighting.allCases) { lighting in
                            Text(lighting.title).tag(lighting)
                        }
                    }

                    if board.lighting != .off {
                        colorRow
                    }
                }

                if canDelete {
                    Section {
                        Button("Delete Board", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Board Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete this board?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Board", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("Its pins stay in your collection.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 420)
        #endif
        // Half-height so the board stays visible, and live, while you adjust it.
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Light Color")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LightColor.allCases) { lightColor in
                        swatch(for: lightColor)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func swatch(for lightColor: LightColor) -> some View {
        let isSelected = board.lightColor == lightColor
        return Button {
            board.lightColor = lightColor
        } label: {
            Circle()
                .fill(lightColor.swatch)
                .frame(width: 32, height: 32)
                .overlay {
                    Circle().strokeBorder(.primary.opacity(isSelected ? 0.9 : 0.15), lineWidth: isSelected ? 3 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lightColor.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    PreviewBoardSettings()
        .modelContainer(previewContainer())
}

/// Shows settings for the first sample board in the preview store.
private struct PreviewBoardSettings: View {
    @Query(sort: \Board.dateCreated) private var boards: [Board]

    var body: some View {
        if let board = boards.first {
            BoardSettingsView(board: board, canDelete: true, onDelete: {})
        }
    }
}
