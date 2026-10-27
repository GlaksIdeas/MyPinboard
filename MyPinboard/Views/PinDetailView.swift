import SwiftUI
import SwiftData

/// One of your own pins, with its details and an Edit button.
struct PinDetailView: View {
    @Bindable var pin: Pin
    @State private var isEditing = false

    var body: some View {
        PinDetailContent(
            snapshot: pin.snapshot,
            boardName: pin.board?.name,
            onAddDetails: { isEditing = true }
        )
        .navigationTitle(pin.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditPinView(pin: pin)
        }
    }
}

/// Everything known about a pin, with its photo front and center. Works from a snapshot, so it
/// shows your own pins and other people's the same way.
struct PinDetailContent: View {
    let snapshot: PinSnapshot
    var boardName: String?
    /// Shown as a button when the pin has no details yet. Nil for pins you can't edit.
    var onAddDetails: (() -> Void)?

    /// Whether the hero shows the inside of a pin that opens, rather than its cover.
    @State private var showsInside = false

    private var originFacts: [PinFact] {
        [
            PinFact(icon: "paintbrush.pointed", title: "Artist", value: snapshot.artist),
            PinFact(icon: "party.popper", title: "Festival", value: snapshot.festivalDescription)
        ]
        .filter { !$0.value.isEmpty }
    }

    private var acquisitionFacts: [PinFact] {
        // Marked unknown reads as "Unknown"; simply not filled in is left out.
        let year = snapshot.yearAcquired.map { String($0) }
            ?? (snapshot.yearAcquiredUnknown == true ? "Unknown" : "")
        let price = snapshot.purchasePrice?.formatted(.currency(code: PinFormat.currencyCode))
            ?? (snapshot.priceUnknown == true ? "Unknown" : "")

        return [
            PinFact(icon: "person.2", title: "Acquired From", value: snapshot.acquiredFrom),
            PinFact(icon: "calendar", title: "Year Acquired", value: year),
            PinFact(icon: "tag", title: "Original Price", value: price)
        ]
        .filter { !$0.value.isEmpty }
    }

    private var displayFacts: [PinFact] {
        [PinFact(icon: "pin", title: "On Board", value: boardName ?? "")]
            .filter { !$0.value.isEmpty }
    }

    private var hasNoDetails: Bool {
        snapshot.notes.isEmpty && originFacts.isEmpty && acquisitionFacts.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero

                if !snapshot.notes.isEmpty {
                    InfoCard(title: "Notes") {
                        Text(snapshot.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                factsCard("Origin", originFacts)
                factsCard("Acquisition", acquisitionFacts)
                factsCard("Display", displayFacts)

                if hasNoDetails, let onAddDetails {
                    Button("Add Details", systemImage: "square.and.pencil", action: onAddDetails)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                }
            }
            .padding(16)
        }
        // A soft wash of the pin's own colors behind the header.
        .background(alignment: .top) {
            PinImageView(data: snapshot.imageData)
                .frame(height: 300)
                .scaleEffect(2.4)
                .blur(radius: 60)
                .opacity(0.4)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipped()
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            PinFaceView(
                data: showsInside ? snapshot.openImageData : snapshot.imageData,
                isShimmery: snapshot.isShimmery ?? false,
                seed: snapshot.id
            )
                .frame(height: 260)
                .shadow(color: .black.opacity(0.3), radius: 24, y: 14)
                .padding(.vertical, 8)
                .animation(.smooth, value: showsInside)
                .accessibilityLabel(snapshot.name)

            // Pins that open can be viewed both ways.
            if snapshot.canOpen {
                Picker("View", selection: $showsInside) {
                    Label("Closed", systemImage: "book.closed").tag(false)
                    Label("Open", systemImage: "book").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            Text(snapshot.name)
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)

            if !snapshot.originSummary.isEmpty {
                Text(snapshot.originSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func factsCard(_ title: String, _ facts: [PinFact]) -> some View {
        if !facts.isEmpty {
            InfoCard(title: title) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(facts) { fact in
                        FactRow(fact: fact)
                    }
                }
            }
        }
    }
}

#Preview {
    PreviewPinDetail()
        .modelContainer(previewContainer())
}

/// Picks the first sample pin out of the preview store.
private struct PreviewPinDetail: View {
    @Query(sort: \Pin.dateAdded) private var pins: [Pin]

    var body: some View {
        NavigationStack {
            if let pin = pins.first {
                PinDetailView(pin: pin)
            }
        }
    }
}

private struct PinFact: Identifiable {
    let icon: String
    let title: String
    let value: String

    var id: String { title }
}

/// A rounded card with a small uppercase heading.
private struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct FactRow: View {
    let fact: PinFact

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fact.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(.tint.opacity(0.15), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(fact.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(fact.value)
                    .font(.body)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Sheet for editing a pin's details. Changes are saved as you type.
struct EditPinView: View {
    @Bindable var pin: Pin
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Retake the photo, or swap it for another; the new one is cut out the same way.
                PinPhotoSection(imageData: $pin.imageData)
                PinInfoFields(pin: pin)
                BoardPickerSection(selection: $pin.board)
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Pin")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(pin.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            // Moving to a different board drops the pin near the middle of it.
            .onChange(of: pin.board?.uuid) { _, newBoardID in
                guard newBoardID != nil else { return }
                pin.positionX = Double.random(in: 0.3...0.7)
                pin.positionY = Double.random(in: 0.3...0.7)
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 480)
        #endif
    }
}
