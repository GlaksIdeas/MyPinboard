import SwiftUI
import SwiftData

/// A searchable grid of every pin in the collection.
struct CollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pin.dateAdded, order: .reverse) private var pins: [Pin]

    @State private var searchText = ""
    @Namespace private var zoomNamespace

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    private var filteredPins: [Pin] {
        guard !searchText.isEmpty else { return pins }
        return pins.filter { pin in
            [pin.name, pin.artist, pin.festival, pin.acquiredFrom, pin.notes]
                .contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderBanner(
                    title: "Collection",
                    subtitle: pins.count == 1 ? "1 pin" : "\(pins.count) pins",
                    color: BannerPalette.collection
                )

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredPins) { pin in
                        NavigationLink(value: pin) {
                            PinCard(pin: pin)
                        }
                        .buttonStyle(.plain)
                        .zoomTransitionSource(id: pin.persistentModelID, in: zoomNamespace)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                modelContext.delete(pin)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .searchable(text: $searchText, prompt: "Search pins")
        .collapsingBannerTitle("Collection")
        .navigationDestination(for: Pin.self) { pin in
            PinDetailView(pin: pin)
                .zoomTransition(sourceID: pin.persistentModelID, in: zoomNamespace)
        }
        .overlay {
            if pins.isEmpty {
                ContentUnavailableView(
                    "No Pins Yet",
                    systemImage: "pin",
                    description: Text("Add a pin to start your collection.")
                )
            } else if filteredPins.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CollectionView()
    }
    .modelContainer(previewContainer())
}

/// A pin's photo on a soft tile with its name and provenance underneath.
private struct PinCard: View {
    let pin: Pin

    private var subtitle: String {
        pin.originSummary.isEmpty ? pin.notes : pin.originSummary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PinFaceView(data: pin.imageData, isShimmery: pin.isShimmery, seed: pin.uuid)
                .shadow(color: .black.opacity(0.22), radius: 6, y: 4)
                .padding(16)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.quaternary.opacity(0.6))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(pin.name)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .lineLimit(1)
                // Always reserve the line so cards in a row stay the same height.
                Text(subtitle.isEmpty ? " " : subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        .padding(8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Marks this view as the origin of a zoom navigation transition (iOS only).
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        matchedTransitionSource(id: id, in: namespace)
        #else
        self
        #endif
    }

    /// Makes this destination zoom out of the matching source (iOS only).
    func zoomTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        #else
        self
        #endif
    }
}
