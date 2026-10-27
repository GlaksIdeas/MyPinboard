import SwiftUI
import SwiftData

private enum AppTab: Hashable {
    case board
    case collection
    case profile
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = AppTab.board
    @State private var isAddingPin = false
    @State private var isChoosingFriendSource = false
    @State private var isImportingFriend = false
    @State private var isPastingLink = false
    @State private var importAlert: ImportAlert?
    /// A pasted link's profile, held until the paste sheet has finished closing so the request can show.
    @State private var pastedCard: ProfileSnapshot?
    /// A profile that has arrived and is waiting for the person to accept or decline it.
    @State private var friendRequest: ProfileSnapshot?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Board", systemImage: "pin", value: AppTab.board) {
                NavigationStack {
                    BoardsScreen()
                        .toolbar { addButton }
                }
            }

            Tab("Collection", systemImage: "square.grid.2x2", value: AppTab.collection) {
                NavigationStack {
                    CollectionView()
                        .toolbar { addButton }
                }
            }

            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .sheet(isPresented: $isAddingPin) {
            AddPinView()
        }
        .environment(\.importFriend, { isChoosingFriendSource = true })
        .confirmationDialog("Add a Friend", isPresented: $isChoosingFriendSource, titleVisibility: .visible) {
            Button("Choose a Profile File…") { isImportingFriend = true }
            Button("Paste a Link…") { isPastingLink = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use a profile someone AirDropped you, or a friend link they sent.")
        }
        // Profiles arrive as files (AirDrop, Messages, the picker) or as friend links. Either way,
        // nobody is added until the person confirms.
        .fileImporter(isPresented: $isImportingFriend, allowedContentTypes: [.pinboardProfile]) { result in
            receiveProfile(from: result)
        }
        .onOpenURL { url in
            if url.isFileURL {
                receiveProfile(from: .success(url))
            } else {
                receiveLink(url)
            }
        }
        .sheet(isPresented: $isPastingLink, onDismiss: showPastedRequest) {
            PasteLinkView { text in
                do {
                    pastedCard = try FriendImporter.readPastedText(text, in: modelContext)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }
        }
        .sheet(item: $friendRequest) { profile in
            FriendRequestView(
                profile: profile,
                isUpdate: FriendImporter.isAlreadyFriend(profile, in: modelContext),
                onAdd: { acceptRequest(profile) },
                onDecline: { friendRequest = nil }
            )
        }
        .alert(
            importAlert?.title ?? "",
            isPresented: Binding(get: { importAlert != nil }, set: { if !$0 { importAlert = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(importAlert?.message ?? "")
        }
        .task { backfillPinIDs() }
        // Warm enamel-orange accent for tab selection, chips, and prominent buttons.
        .tint(Color(red: 0.93, green: 0.45, blue: 0.18))
        #if os(iOS)
        // Let the tab bar tuck away while browsing the collection.
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
    }

    /// Reads an arrived profile file and asks the person whether to add it.
    private func receiveProfile(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let profile = try FriendImporter.readProfile(from: url, in: modelContext)
            presentRequestSoon(profile)
        } catch {
            importAlert = ImportAlert(title: "Couldn't Open Profile", message: error.localizedDescription)
        }
    }

    /// Reads a friend link that opened the app and asks the person whether to add it.
    private func receiveLink(_ url: URL) {
        do {
            presentRequestSoon(try FriendImporter.readLink(url, in: modelContext))
        } catch {
            importAlert = ImportAlert(title: "Couldn't Open Link", message: error.localizedDescription)
        }
    }

    /// Shows the request once the paste sheet has closed; a second sheet can't open on top of the first.
    private func showPastedRequest() {
        guard let card = pastedCard else { return }
        pastedCard = nil
        friendRequest = card
    }

    /// Waits a beat so a closing file picker or dialog doesn't swallow the request sheet.
    private func presentRequestSoon(_ profile: ProfileSnapshot) {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            friendRequest = profile
        }
    }

    private func acceptRequest(_ profile: ProfileSnapshot) {
        do {
            try FriendImporter.add(profile, into: modelContext)
            friendRequest = nil
            // Take them to the new friend in their list.
            selectedTab = .profile
        } catch {
            friendRequest = nil
            importAlert = ImportAlert(title: "Couldn't Add Friend", message: error.localizedDescription)
        }
    }

    /// Pins made before they had stable IDs all share one default ID; give each its own.
    private func backfillPinIDs() {
        guard let pins = try? modelContext.fetch(FetchDescriptor<Pin>()) else { return }
        var seen = Set<UUID>()
        for pin in pins where !seen.insert(pin.uuid).inserted {
            pin.uuid = UUID()
        }
    }

    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Pin", systemImage: "plus") {
                isAddingPin = true
            }
        }
    }
}

private struct ImportAlert {
    let title: String
    let message: String
}

#Preview {
    ContentView()
        .modelContainer(previewContainer())
}

/// An in-memory store with a couple of boards and sample pins, so previews show real content.
@MainActor
func previewContainer() -> ModelContainer {
    // Previews stay local; they must never touch the real iCloud container.
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    guard let container = try? ModelContainer(
        for: Pin.self, Board.self, Profile.self, Friend.self,
        configurations: configuration
    ) else {
        fatalError("Couldn't create the preview container")
    }
    let context = container.mainContext

    let main = Board(name: "Convention Haul")
    main.lighting = .ledStrip
    main.lightColor = .rainbow
    main.wall = .brickRed
    let side = Board(name: "Favorites")
    context.insert(main)
    context.insert(side)

    let samples: [(name: String, artist: String, festival: String, year: Int, x: Double, y: Double, rotation: Double)] = [
        ("Sunset Fox", "Mika Tanaka", "AnthroCon", 2023, 0.28, 0.25, -8),
        ("Neon Wolf", "Rae Vega", "Furpocalypse", 2022, 0.68, 0.32, 10),
        ("Moth Queen", "Juno Park", "MFF", 2024, 0.45, 0.55, -4),
        ("Tiny Dragon", "Ollie Finch", "Eurofurence", 2021, 0.22, 0.75, 12),
        ("Space Cat", "Pim Lowe", "AnthroCon", 2024, 0.74, 0.78, -12),
        // Saved right at the edges, to check pins stay fully visible instead of sliding under the frame.
        ("Corner Bat", "Mika Tanaka", "AnthroCon", 2023, 0.0, 0.0, 15),
        ("Edge Owl", "Rae Vega", "MFF", 2024, 1.0, 0.95, -20)
    ]
    for (index, sample) in samples.enumerated() {
        let pin = Pin(name: sample.name, notes: "")
        pin.artist = sample.artist
        pin.festival = sample.festival
        pin.festivalYear = sample.year
        pin.yearAcquired = sample.year
        pin.purchasePrice = Double(12 + index * 3)
        pin.acquiredFrom = "Artist Alley"
        pin.positionX = sample.x
        pin.positionY = sample.y
        pin.rotation = sample.rotation

        // A few special pins, to show glitter and pins that open.
        if sample.name == "Sunset Fox" {
            pin.isShimmery = true
        }
        if sample.name == "Moth Queen" {
            pin.opensLikeBook = true
            pin.imageData = PinArtSamples.cover
            pin.openImageData = PinArtSamples.spread
            pin.isOpen = true
        }
        if sample.name == "Space Cat" {
            pin.opensLikeBook = true
            pin.isShimmery = true
            pin.imageData = PinArtSamples.cover
            pin.openImageData = PinArtSamples.spread
        }
        context.insert(pin)
        pin.board = main
    }

    let me = Profile()
    me.displayName = "Sam Rivera"
    me.handle = "sam.pins"
    me.bio = "Fox pins and festival hauls. AnthroCon regular."
    context.insert(me)

    // A friend, built from separate sample models that never enter the store.
    let friendProfile = Profile()
    friendProfile.displayName = "Ollie Finch"
    friendProfile.handle = "ollie_finch"
    friendProfile.bio = "Dragons, mostly."
    let friendBoard = Board(name: "Dragon Hoard")
    friendBoard.style = .felt
    friendBoard.wall = .planks
    friendBoard.lighting = .ambientGlow
    friendBoard.lightColor = .purple
    let friendPins = [("Tiny Dragon", 0.3, 0.3), ("Ember Wyrm", 0.65, 0.5), ("Hoard Cat", 0.35, 0.72)].map { entry -> Pin in
        let pin = Pin(name: entry.0)
        pin.artist = "Ollie Finch"
        pin.positionX = entry.1
        pin.positionY = entry.2
        return pin
    }
    friendBoard.pins = friendPins
    let friend = Friend(profile: ProfileSnapshot(profile: friendProfile, boards: [friendBoard], pins: friendPins))
    friend.topRank = 1
    context.insert(friend)

    return container
}
