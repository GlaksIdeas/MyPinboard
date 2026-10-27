import Foundation
import SwiftData

/// A physically collected pin, photographed and placed on the board.
@Model
final class Pin {
    /// Stable identity for sharing and syncing. Existing pins are backfilled with unique values on launch.
    var uuid: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var dateAdded: Date = Date.now

    /// Photo of the pin. Later this will be the background-removed cutout.
    @Attribute(.externalStorage) var imageData: Data?

    /// Board placement. Position is normalized (0...1) so the layout
    /// adapts to any window size across iPhone, iPad, and Mac.
    var positionX: Double = 0.5
    var positionY: Double = 0.5
    var rotation: Double = 0
    var scale: Double = 1

    /// Provenance details.
    var artist: String = ""
    var festival: String = ""
    var festivalYear: Int?
    var acquiredFrom: String = ""
    var yearAcquired: Int?
    var purchasePrice: Double?
    /// "I don't know" is different from "I haven't filled it in", so it's recorded separately.
    var yearAcquiredUnknown: Bool = false
    var priceUnknown: Bool = false

    /// Glittery pins get a shimmer.
    var isShimmery: Bool = false

    /// Some pins open like a book. `openImageData` is a photo of the pin fully open, both pages side by
    /// side, with the closed pin matching the right-hand page. `isOpen` is whether it's showing open.
    var opensLikeBook: Bool = false
    @Attribute(.externalStorage) var openImageData: Data?
    var isOpen: Bool = false

    /// The board this pin is displayed on, if any.
    var board: Board?

    /// "AnthroCon 2023", or just the name or year if only one is known.
    var festivalDescription: String {
        PinText.festivalDescription(festival: festival, year: festivalYear)
    }

    /// Short "Artist · Festival Year" line for lists.
    var originSummary: String {
        PinText.originSummary(artist: artist, festival: festival, year: festivalYear)
    }

    /// Whether the pin can be opened: it's marked as opening, and there's a photo of the inside.
    var canOpen: Bool {
        opensLikeBook && openImageData != nil
    }

    /// A plain-data copy, safe to share or show outside the store.
    @MainActor
    var snapshot: PinSnapshot {
        PinSnapshot(self)
    }

    init(name: String, notes: String = "", imageData: Data? = nil) {
        self.name = name
        self.notes = notes
        self.imageData = imageData
    }
}
