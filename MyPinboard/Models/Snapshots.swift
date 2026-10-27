import Foundation

// Plain-data copies of the store's models. Screens that show someone else's pins and boards
// render from these, so they work the same whether the data came from this device or, later,
// from another person. They're Codable so a profile can be exchanged as a file.

/// Wording shared by pins and their snapshots.
nonisolated enum PinText {
    /// "AnthroCon 2023", or just the name or year if only one is known.
    static func festivalDescription(festival: String, year: Int?) -> String {
        [festival, year.map(String.init) ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Short "Artist · Festival Year" line for lists.
    static func originSummary(artist: String, festival: String, year: Int?) -> String {
        [artist, festivalDescription(festival: festival, year: year)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

nonisolated struct PinSnapshot: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var imageData: Data?
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var scale: Double
    var artist: String
    var festival: String
    var festivalYear: Int?
    var acquiredFrom: String
    var yearAcquired: Int?
    var purchasePrice: Double?
    var dateAdded: Date
    // Added later, so optional: profiles saved before they existed still read fine.
    var isShimmery: Bool?
    var opensLikeBook: Bool?
    var openImageData: Data?
    var isOpen: Bool?
    var yearAcquiredUnknown: Bool?
    var priceUnknown: Bool?

    /// Whether the pin can be opened: it's marked as opening, and there's a photo of the inside.
    var canOpen: Bool {
        opensLikeBook == true && openImageData != nil
    }

    @MainActor
    init(_ pin: Pin) {
        id = pin.uuid
        name = pin.name
        notes = pin.notes
        imageData = pin.imageData
        positionX = pin.positionX
        positionY = pin.positionY
        rotation = pin.rotation
        scale = pin.scale
        artist = pin.artist
        festival = pin.festival
        festivalYear = pin.festivalYear
        acquiredFrom = pin.acquiredFrom
        yearAcquired = pin.yearAcquired
        purchasePrice = pin.purchasePrice
        dateAdded = pin.dateAdded
        isShimmery = pin.isShimmery
        opensLikeBook = pin.opensLikeBook
        openImageData = pin.openImageData
        isOpen = pin.isOpen
        yearAcquiredUnknown = pin.yearAcquiredUnknown
        priceUnknown = pin.priceUnknown
    }

    var festivalDescription: String {
        PinText.festivalDescription(festival: festival, year: festivalYear)
    }

    var originSummary: String {
        PinText.originSummary(artist: artist, festival: festival, year: festivalYear)
    }
}

/// How a board looks: its surface, frame, lighting, and the wall behind it.
nonisolated struct BoardAppearance: Codable, Hashable {
    var style: BoardStyle
    var customBoardData: Data?
    var showShadowbox: Bool
    var lighting: BoardLighting
    var lightColor: LightColor
    var wall: WallStyle
    var customWallData: Data?
}

nonisolated struct BoardSnapshot: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var appearance: BoardAppearance
    var pins: [PinSnapshot]

    @MainActor
    init(_ board: Board) {
        id = board.uuid
        name = board.name
        appearance = board.appearance
        pins = (board.pins ?? [])
            .sorted { $0.dateAdded < $1.dateAdded }
            .map(PinSnapshot.init)
    }
}

/// Headline numbers about a collection.
nonisolated struct CollectionStats: Codable, Hashable {
    var pinCount: Int
    var boardCount: Int
    var festivalCount: Int
    var artistCount: Int
    /// Sum of original purchase prices, for pins that have one.
    var totalValue: Double

    init(pinCount: Int, boardCount: Int, festivalCount: Int, artistCount: Int, totalValue: Double) {
        self.pinCount = pinCount
        self.boardCount = boardCount
        self.festivalCount = festivalCount
        self.artistCount = artistCount
        self.totalValue = totalValue
    }

    static let empty = CollectionStats(pinCount: 0, boardCount: 0, festivalCount: 0, artistCount: 0, totalValue: 0)

    @MainActor
    init(pins: [Pin], boardCount: Int) {
        pinCount = pins.count
        self.boardCount = boardCount
        festivalCount = Set(pins.map(\.festival).filter { !$0.isEmpty }).count
        artistCount = Set(pins.map(\.artist).filter { !$0.isEmpty }).count
        totalValue = pins.compactMap(\.purchasePrice).reduce(0, +)
    }
}

/// Everything someone sees when they visit a profile.
nonisolated struct ProfileSnapshot: Codable, Identifiable, Hashable {
    /// Identifies the person across exports, so re-importing a profile updates it instead of duplicating it.
    var id: UUID
    var displayName: String
    var handle: String
    var bio: String
    var avatarData: Data?
    var dateJoined: Date
    var stats: CollectionStats
    var boards: [BoardSnapshot]
    /// Version of this format, so other apps (web, Android) know which fields to expect.
    var formatVersion: Int?
    /// True when only a name card arrived, by link, so boards and stats are missing.
    var cardOnly: Bool?

    /// A name card: who they are, without boards or stats. This is all a link can carry.
    init(id: UUID, displayName: String, handle: String, bio: String, avatarData: Data?) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.bio = bio
        self.avatarData = avatarData
        dateJoined = Date.now
        stats = .empty
        boards = []
        formatVersion = 1
        cardOnly = true
    }

    @MainActor
    init(profile: Profile, boards: [Board], pins: [Pin]) {
        formatVersion = 1
        id = profile.uuid
        displayName = profile.displayName
        handle = profile.handle
        bio = profile.bio
        avatarData = profile.avatarData
        dateJoined = profile.dateJoined
        stats = CollectionStats(pins: pins, boardCount: boards.count)
        self.boards = boards.map(BoardSnapshot.init)
    }
}
