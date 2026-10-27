import SwiftUI
import CoreTransferable
import ImageIO
import UniformTypeIdentifiers

// How boards and profiles leave the app: a board as a picture, a profile as a small file
// that someone else can open to add you to their network.

extension UTType {
    /// A profile exchanged between people. Declared as an exported type in the app's Info.plist.
    static let pinboardProfile = UTType(exportedAs: "com.pinboard.profile")
}

extension ProfileSnapshot: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(
            contentType: .pinboardProfile,
            encoder: ProfileCoding.encoder,
            decoder: ProfileCoding.decoder
        )
    }
}

/// A board rendered as a shareable picture, made only when someone actually shares it.
struct BoardImage: Transferable {
    let board: BoardSnapshot
    /// Shown under the board, e.g. "@sam".
    var credit: String?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            try await image.pngData()
        }
    }

    @MainActor
    func pngData() throws -> Data {
        let renderer = ImageRenderer(content: ExportedBoardView(board: board, credit: credit))
        renderer.scale = 2

        guard let cgImage = renderer.cgImage else { throw SharingError.renderFailed }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        ) else { throw SharingError.renderFailed }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw SharingError.renderFailed }
        return output as Data
    }
}

enum SharingError: Error {
    case renderFailed
}

/// The board on its wall, with its name and who it belongs to. Fixed size, with the lights held still.
private struct ExportedBoardView: View {
    let board: BoardSnapshot
    let credit: String?

    var body: some View {
        ZStack {
            BoardWall(style: board.appearance.wall, customData: board.appearance.customWallData)

            VStack(spacing: 0) {
                BoardCanvas(
                    appearance: board.appearance,
                    isEmpty: board.pins.isEmpty,
                    emptyMessage: "Nothing is pinned here yet.",
                    contentInsets: EdgeInsets(top: 48, leading: 48, bottom: 24, trailing: 48)
                ) { size in
                    ForEach(board.pins) { pin in
                        StaticPinView(pin: pin, boardSize: size)
                    }
                } overlay: {
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(board.name)
                        .font(.title2.bold())
                        .fontDesign(.rounded)
                    Spacer()
                    if let credit, !credit.isEmpty {
                        Text(credit)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 40)
            }
        }
        .frame(width: 800, height: 1000)
        .environment(\.boardLightingPaused, true)
        .environment(\.colorScheme, .dark)
    }
}
