import Foundation
import SwiftData

/// A named board that pins are arranged on, with its own surface and lighting.
@Model
final class Board {
    /// Stable identifier used to remember which board is selected.
    var uuid: UUID = UUID()
    var name: String = ""
    var dateCreated: Date = Date.now

    var styleRaw: String = BoardStyle.cork.rawValue
    var showShadowbox: Bool = true
    var lightingRaw: String = BoardLighting.off.rawValue
    var lightColorRaw: String = LightColor.warmWhite.rawValue
    var wallRaw: String = WallStyle.plaster.rawValue

    /// Photos people upload themselves, for the board surface and the wall behind it.
    @Attribute(.externalStorage) var customBoardData: Data?
    @Attribute(.externalStorage) var customWallData: Data?

    /// Deleting a board leaves its pins in the collection, just off any board.
    /// Optional because CloudKit requires every relationship to be.
    @Relationship(inverse: \Pin.board) var pins: [Pin]? = []

    var style: BoardStyle {
        get { BoardStyle(rawValue: styleRaw) ?? .cork }
        set { styleRaw = newValue.rawValue }
    }

    /// Everything about how the board looks, as plain data.
    var appearance: BoardAppearance {
        BoardAppearance(
            style: style,
            customBoardData: customBoardData,
            showShadowbox: showShadowbox,
            lighting: lighting,
            lightColor: lightColor,
            wall: wall,
            customWallData: customWallData
        )
    }

    var wall: WallStyle {
        get { WallStyle(rawValue: wallRaw) ?? .plaster }
        set { wallRaw = newValue.rawValue }
    }

    var lighting: BoardLighting {
        get { BoardLighting(rawValue: lightingRaw) ?? .off }
        set { lightingRaw = newValue.rawValue }
    }

    var lightColor: LightColor {
        get { LightColor(rawValue: lightColorRaw) ?? .warmWhite }
        set { lightColorRaw = newValue.rawValue }
    }

    init(name: String) {
        self.name = name
    }
}
