import SwiftUI
import SwiftData

enum PinFormat {
    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

/// Form sections for a pin's name, notes, and provenance. Shared by adding and editing.
struct PinInfoFields: View {
    @Bindable var pin: Pin

    var body: some View {
        Section("Details") {
            TextField("Name", text: $pin.name)
            TextField("Notes", text: $pin.notes, axis: .vertical)
                .lineLimit(2...5)
        }

        Section("Origin") {
            TextField("Artist", text: $pin.artist)
            TextField("Festival or Event", text: $pin.festival)
            TextField("Festival Year", value: $pin.festivalYear, format: .number.grouping(.never))
                .numericKeyboard()
        }

        Section("Acquisition") {
            TextField("Acquired From", text: $pin.acquiredFrom)

            TextField("Year Acquired", value: $pin.yearAcquired, format: .number.grouping(.never))
                .numericKeyboard()
                .disabled(pin.yearAcquiredUnknown)
            Toggle("Year unknown", isOn: $pin.yearAcquiredUnknown)

            TextField("Original Price", value: $pin.purchasePrice, format: .currency(code: PinFormat.currencyCode))
                .numericKeyboard(decimal: true)
                .disabled(pin.priceUnknown)
            Toggle("Price unknown", isOn: $pin.priceUnknown)
        }
        // Marking something unknown clears any value typed before, so the two never disagree.
        .onChange(of: pin.yearAcquiredUnknown) { _, unknown in
            if unknown { pin.yearAcquired = nil }
        }
        .onChange(of: pin.priceUnknown) { _, unknown in
            if unknown { pin.purchasePrice = nil }
        }

        Section {
            Toggle("Glittery", systemImage: "sparkles", isOn: $pin.isShimmery)
            Toggle("Opens like a book", systemImage: "book", isOn: $pin.opensLikeBook)
        } header: {
            Text("Special Features")
        } footer: {
            Text("Glittery pins shimmer and sparkle. Pins that open can be opened and closed on your board.")
        }

        if pin.opensLikeBook {
            PinPhotoSection(
                imageData: $pin.openImageData,
                header: "Inside Photo",
                hint: "Photograph the pin fully open, both pages side by side, with the cover on the right.",
                previewAspect: 2,
                canRemove: true
            )
        }
    }
}

/// Form section for choosing which board a pin lives on.
struct BoardPickerSection: View {
    @Binding var selection: Board?
    @Query(sort: \Board.dateCreated) private var boards: [Board]

    var body: some View {
        Section("Board") {
            Picker("Board", selection: $selection) {
                Text("None").tag(Board?.none)
                ForEach(boards) { board in
                    Text(board.name.isEmpty ? "Untitled Board" : board.name).tag(Optional(board))
                }
            }
        }
    }
}

private extension View {
    func numericKeyboard(decimal: Bool = false) -> some View {
        #if os(iOS)
        keyboardType(decimal ? .decimalPad : .numberPad)
        #else
        self
        #endif
    }
}
