import SwiftUI
import SwiftData

/// Sheet for adding a pin from a camera shot or a photo from the library.
/// The pin is automatically cut out from its background.
struct AddPinView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Board.dateCreated) private var boards: [Board]
    @AppStorage("selectedBoardID") private var currentBoardID = ""

    /// Edited in place and only inserted into the store on save.
    @State private var draft = Pin(name: "")
    @State private var selectedBoard: Board?
    @State private var imageData: Data?
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            Form {
                PinPhotoSection(imageData: $imageData, isBusy: $isProcessing)

                PinInfoFields(pin: draft)

                BoardPickerSection(selection: $selectedBoard)
            }
            .formStyle(.grouped)
            .navigationTitle("Add Pin")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
                }
            }
            // New pins go on whichever board is currently showing.
            .task {
                selectedBoard = boards.first { $0.uuid.uuidString == currentBoardID } ?? boards.first
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        draft.imageData = imageData
        // Scatter new pins near the center so they don't stack exactly.
        draft.positionX = Double.random(in: 0.3...0.7)
        draft.positionY = Double.random(in: 0.3...0.7)
        draft.rotation = Double.random(in: -15...15)
        modelContext.insert(draft)
        // Relate to the board only once the pin is in the store.
        draft.board = selectedBoard
        dismiss()
    }
}
