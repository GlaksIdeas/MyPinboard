import SwiftUI
import PhotosUI

/// What hangs behind the board: a photographed wall, a solid color, or the person's own photo.
nonisolated enum WallStyle: String, CaseIterable, Identifiable, Codable {
    /// Soft painted plaster that follows light and dark appearance.
    case plaster
    case brickRed
    case brickWhite
    case concrete
    case roughPlaster
    case planks
    case navy
    case sage
    case blush
    case mustard
    case charcoal
    /// The board's own uploaded photo.
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plaster: "Classic"
        case .brickRed: "Red Brick"
        case .brickWhite: "White Brick"
        case .concrete: "Concrete"
        case .roughPlaster: "Plaster"
        case .planks: "Wood"
        case .navy: "Navy"
        case .sage: "Sage"
        case .blush: "Blush"
        case .mustard: "Mustard"
        case .charcoal: "Charcoal"
        case .custom: "My Photo"
        }
    }

    /// Built-in walls; `.custom` only applies once a photo has been uploaded.
    static var presets: [WallStyle] {
        allCases.filter { $0 != .custom }
    }

    /// Seamless photo textures (ambientCG, CC0) from the asset catalog.
    var photoAsset: String? {
        switch self {
        case .brickRed: "WallBrickRed"
        case .brickWhite: "WallBrickWhite"
        case .concrete: "WallConcrete"
        case .roughPlaster: "WallPlaster"
        case .planks: "WallPlanks"
        default: nil
        }
    }

    /// How large the tiled photo appears; smaller is finer.
    var photoScale: Double {
        switch self {
        case .brickRed, .brickWhite: 0.45
        default: 0.5
        }
    }

    /// Top and bottom colors for the solid walls.
    var solidColors: [Color]? {
        switch self {
        case .navy: [Color(red: 0.16, green: 0.24, blue: 0.42), Color(red: 0.07, green: 0.11, blue: 0.24)]
        case .sage: [Color(red: 0.58, green: 0.68, blue: 0.55), Color(red: 0.42, green: 0.52, blue: 0.40)]
        case .blush: [Color(red: 0.93, green: 0.76, blue: 0.76), Color(red: 0.82, green: 0.62, blue: 0.64)]
        case .mustard: [Color(red: 0.86, green: 0.67, blue: 0.22), Color(red: 0.70, green: 0.50, blue: 0.12)]
        case .charcoal: [Color(red: 0.22, green: 0.22, blue: 0.24), Color(red: 0.11, green: 0.11, blue: 0.13)]
        default: nil
        }
    }
}

/// The wall the board hangs on, with a soft spotlight above the board.
/// Replaces the system's flat background so the board always has somewhere to hang.
struct BoardWall: View {
    let style: WallStyle
    /// The uploaded photo, used when `style` is `.custom`.
    var customData: Data?

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            surface

            // Spotlight washing the wall behind the board.
            RadialGradient(
                colors: [.white.opacity(isDark ? 0.10 : 0.40), .clear],
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0,
                endRadius: 520
            )
        }
    }

    @ViewBuilder
    private var surface: some View {
        if style == .custom, let customData {
            Color.clear
                .overlay { DataImage(data: customData) }
                .clipped()
                // Keeps the chips and toolbar readable over busy photos.
                .overlay(Color.black.opacity(isDark ? 0.3 : 0.06))
        } else if let asset = style.photoAsset {
            Rectangle()
                .fill(ImagePaint(image: Image(asset), scale: style.photoScale))
                // Bright photos are dimmed in dark mode so they don't glare around the board.
                .overlay(Color.black.opacity(isDark ? 0.4 : 0))
        } else if let colors = style.solidColors {
            ZStack {
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                grain
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: isDark
                        ? [Color(red: 0.17, green: 0.17, blue: 0.20), Color(red: 0.08, green: 0.08, blue: 0.10)]
                        : [Color(red: 0.94, green: 0.92, blue: 0.89), Color(red: 0.84, green: 0.82, blue: 0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                grain
            }
        }
    }

    /// Fine plaster grain.
    private var grain: some View {
        Canvas { context, size in
            var rng = SeededGenerator(seed: 99)
            let count = Int(min(max(size.width * size.height / 30, 2000), 20000))
            for _ in 0..<count {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let s = Double.random(in: 0.6...1.6, using: &rng)
                let light = Bool.random(using: &rng)
                let tone: Color = light ? .white.opacity(isDark ? 0.05 : 0.3) : .black.opacity(isDark ? 0.22 : 0.06)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(tone))
            }
        }
    }
}

/// A grid of wall choices, each shown as a small swatch.
struct WallPicker: View {
    @Binding var selection: WallStyle
    /// When there's an uploaded photo it's offered as one more choice.
    let customData: Data?

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 12)]

    private var choices: [WallStyle] {
        customData == nil ? WallStyle.presets : WallStyle.presets + [.custom]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(choices) { style in
                swatch(for: style)
            }
        }
        .padding(.vertical, 4)
    }

    private func swatch(for style: WallStyle) -> some View {
        let isSelected = selection == style
        return Button {
            selection = style
        } label: {
            VStack(spacing: 6) {
                WallSwatch(style: style, customData: customData)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                          lineWidth: isSelected ? 3 : 1)
                    }
                Text(style.title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small preview of a wall style.
private struct WallSwatch: View {
    let style: WallStyle
    let customData: Data?

    var body: some View {
        if style == .custom {
            Color.clear.overlay { DataImage(data: customData) }
                .clipped()
        } else if let asset = style.photoAsset {
            Color.clear.overlay {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
        } else if let colors = style.solidColors {
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
        } else {
            // Classic adapts to appearance, so show both halves.
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.92, blue: 0.89), Color(red: 0.17, green: 0.17, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// Rows for choosing, replacing, or removing an uploaded photo. Photos are shrunk before they're stored.
struct CustomPhotoRow: View {
    let title: String
    @Binding var data: Data?
    /// The longest side, in pixels, that a stored photo is shrunk to.
    var maxDimension: CGFloat = 2048
    /// Called after a new photo has been stored, so the caller can switch to it.
    let onChosen: () -> Void
    /// Called after the photo is removed, so the caller can fall back to a built-in choice.
    let onRemoved: () -> Void

    @State private var item: PhotosPickerItem?
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            HStack {
                Label(data == nil ? title : "Change Photo", systemImage: "photo.badge.plus")
                Spacer()
                if isLoading {
                    ProgressView()
                }
            }
        }
        .task(id: item) {
            guard let item else { return }
            isLoading = true
            didFail = false
            defer {
                isLoading = false
                self.item = nil
            }
            guard let original = try? await item.loadTransferable(type: Data.self),
                  let scaled = await Task.detached(operation: {
                      ImageDownscaler.jpegData(from: original, maxDimension: maxDimension)
                  }).value
            else {
                didFail = true
                return
            }
            data = scaled
            onChosen()
        }

        if didFail {
            Text("That photo couldn't be loaded. Try a different one.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if data != nil {
            Button("Remove Photo", role: .destructive) {
                data = nil
                onRemoved()
            }
        }
    }
}
