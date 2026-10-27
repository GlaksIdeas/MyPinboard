import SwiftUI
import SwiftData

/// Your own profile: how you appear to friends, your collection's numbers, and your boards,
/// plus the people you've added. Expects to be placed inside a NavigationStack.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]
    @Query(sort: \Board.dateCreated) private var boards: [Board]
    @Query private var pins: [Pin]

    @State private var isEditing = false
    @State private var isShowingOptions = false

    var body: some View {
        ScrollView {
            if let profile = profiles.first {
                let snapshot = ProfileSnapshot(profile: profile, boards: boards, pins: pins)
                ProfileContent(
                    profile: snapshot,
                    credit: profile.handle.isEmpty ? nil : "@\(profile.handle)",
                    emptyNamePrompt: "Add your name"
                ) {
                    VStack(spacing: 16) {
                        Button("Edit Profile", systemImage: "pencil") { isEditing = true }
                            .buttonStyle(.glass)

                        ShareProfileCard(profile: snapshot)
                    }
                } footer: {
                    FriendsSection()
                }
            }
        }
        .collapsingBannerTitle(
            profiles.first.map { $0.displayName.isEmpty ? "Profile" : $0.displayName } ?? "Profile",
            bannerHeight: 90
        )
        .navigationDestination(for: Friend.self) { friend in
            FriendProfileView(friend: friend)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Options", systemImage: "gearshape") { isShowingOptions = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let profile = profiles.first {
                EditProfileView(profile: profile)
            }
        }
        .sheet(isPresented: $isShowingOptions) {
            OptionsView()
        }
        // The profile is created the first time this tab opens.
        .task {
            if profiles.isEmpty {
                modelContext.insert(Profile())
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(previewContainer())
}

#Preview("Scrolled to boards and friends") {
    NavigationStack {
        ProfileView()
            .defaultScrollAnchor(.bottom)
    }
    .modelContainer(previewContainer())
}

/// Explains and starts adding friends by AirDrop: you send your profile, and they choose to add you.
private struct ShareProfileCard: View {
    let profile: ProfileSnapshot

    @State private var didCopyLink = false
    @AppStorage("showSharingTips") private var showTips = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.2.wave.2")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 40, height: 40)
                    .background(.tint.opacity(0.15), in: .circle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add friends by AirDrop")
                        .font(.headline)
                    Text("Nobody can find you unless you send them your profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if showTips {
                    Spacer(minLength: 0)
                    Button("Hide tips", systemImage: "xmark") {
                        withAnimation(.smooth) { showTips = false }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                }
            }

            if showTips {
                VStack(alignment: .leading, spacing: 8) {
                    step(1, "Tap Share My Profile and choose AirDrop.")
                    step(2, "Pick your friend's phone. If it doesn't show, they can set AirDrop to Everyone for 10 Minutes.")
                    step(3, "They tap Accept, then Add Friend.")
                }
                .transition(.opacity)
            }

            ShareLink(
                item: profile,
                preview: SharePreview(profile.displayName.isEmpty ? "My Pinboard Profile" : profile.displayName)
            ) {
                Label("Share My Profile", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)

            if let link = ProfileLink.url(for: profile) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ShareLink(item: link, subject: Text("Add me on Pinboard")) {
                            Label("Share Link", systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        Button {
                            Clipboard.copy(link.absoluteString)
                            didCopyLink = true
                        } label: {
                            Label(
                                didCopyLink ? "Copied" : "Copy Link",
                                systemImage: didCopyLink ? "checkmark" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .sensoryFeedback(.success, trigger: didCopyLink)
                    }

                    if showTips {
                        Text("A link is the backup for when AirDrop isn't an option. It carries your name and photo, not your boards.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if showTips {
                Text("Want to add someone? Ask them to AirDrop you their profile, or send you their link.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        // Puts the "Copied" label back after a moment.
        .task(id: didCopyLink) {
            guard didCopyLink else { return }
            try? await Task.sleep(for: .seconds(2))
            didCopyLink = false
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.tint, in: .circle)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }
}

/// A profile as visitors see it: avatar, name, stats, and boards. Works from a snapshot, so it shows
/// your own profile and a friend's the same way.
struct ProfileContent<Actions: View, Footer: View>: View {
    let profile: ProfileSnapshot
    /// Shown on shared board images, e.g. "@sam".
    var credit: String?
    var emptyNamePrompt = "Collector"
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            // A solid banner in this person's color. It scrolls away with the page, and the
            // avatar below overlaps its bottom edge.
            Color.clear
                .frame(height: 110)
                .background(alignment: .bottom) {
                    BannerSurface(color: BannerPalette.color(for: profile.id))
                }
                .accessibilityHidden(true)

            VStack(spacing: 28) {
                header
                actions()

                if profile.cardOnly == true {
                    CardOnlyNote()
                } else {
                    StatsRow(stats: profile.stats)
                }

                if !profile.boards.isEmpty {
                    BoardsGrid(boards: profile.boards, credit: credit)
                }

                footer()
            }
            .padding(16)
            .frame(maxWidth: 700)
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(spacing: 10) {
            AvatarView(data: profile.avatarData, name: profile.displayName, size: 104)
                // A ring in the page's color separates the avatar from the banner it overlaps.
                .padding(5)
                .background(.background, in: Circle())
                .offset(y: -56)
                .padding(.bottom, -56)

            Text(profile.displayName.isEmpty ? emptyNamePrompt : profile.displayName)
                .font(.title.bold())
                .fontDesign(.rounded)
                .foregroundStyle(profile.displayName.isEmpty ? .secondary : .primary)

            if !profile.handle.isEmpty {
                Text("@\(profile.handle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Text("Collecting since \(profile.dateJoined.formatted(.dateTime.year()))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Explains that a friend link only brought a name and photo, with no boards or stats.
struct CardOnlyNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Only their name and photo have arrived. Ask them to AirDrop you their full profile to see their boards and collection.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// A person's photo, or their initials when they haven't set one.
struct AvatarView: View {
    let data: Data?
    let name: String
    let size: CGFloat

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    var body: some View {
        ZStack {
            if data != nil {
                Color.clear.overlay { DataImage(data: data) }
                    .clipped()
            } else {
                LinearGradient(
                    colors: [.accentColor, .accentColor.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if initials.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1) }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

/// The headline numbers about a collection.
struct StatsRow: View {
    let stats: CollectionStats

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(value: stats.pinCount, label: "Pins")
                StatTile(value: stats.boardCount, label: "Boards")
                StatTile(value: stats.festivalCount, label: "Festivals")
                StatTile(value: stats.artistCount, label: "Artists")
            }

            if stats.totalValue > 0 {
                HStack {
                    Label("Collection value", systemImage: "tag")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stats.totalValue.formatted(.currency(code: PinFormat.currencyCode).precision(.fractionLength(0))))
                        .font(.headline)
                        .fontDesign(.rounded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(.title2.bold())
                .fontDesign(.rounded)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A grid of board thumbnails. Tapping one enlarges it into a full-screen viewer, where you can
/// swipe to the other boards.
struct BoardsGrid: View {
    let boards: [BoardSnapshot]
    var credit: String?

    @Namespace private var zoomNamespace
    @State private var viewer: BoardViewerRequest?
    /// The board showing in the viewer. The viewer zooms back into this one's thumbnail when closed.
    @State private var viewerPage = UUID()

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Boards")
                .font(.title3.bold())
                .fontDesign(.rounded)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(boards) { board in
                    Button {
                        viewerPage = board.id
                        viewer = BoardViewerRequest(id: board.id)
                    } label: {
                        BoardThumbnail(board: board)
                    }
                    .buttonStyle(.plain)
                    .zoomTransitionSource(id: board.id, in: zoomNamespace)
                    .accessibilityHint("Opens the board full screen")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardViewer(item: $viewer) { _ in
            BoardPagerView(boards: boards, selection: $viewerPage, credit: credit)
                .zoomTransition(sourceID: viewerPage, in: zoomNamespace)
        }
    }
}

/// Identifies which board a viewer was opened on.
struct BoardViewerRequest: Identifiable {
    let id: UUID
}

private extension View {
    /// Presents the board viewer full screen on iOS, and as a sheet on the Mac.
    func boardViewer<Content: View>(
        item: Binding<BoardViewerRequest?>,
        @ViewBuilder content: @escaping (BoardViewerRequest) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }
}

/// A miniature of just the board, without its wall. The full board is laid out at a fixed size and
/// scaled down; pins are sized and placed relative to the board, so they keep their proportions
/// and stay fully on it at any thumbnail size.
private struct BoardThumbnail: View {
    let board: BoardSnapshot

    private let canvasSize = CGSize(width: 360, height: 460)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let scale = geometry.size.width / canvasSize.width
                // The board is laid out at its full size inside an overlay, so it can't change the
                // tile's own size, then scaled down from the top-left corner to fit.
                Color.clear
                    .overlay(alignment: .topLeading) {
                        BoardCanvas(
                            appearance: board.appearance,
                            isEmpty: false,
                            contentInsets: EdgeInsets()
                        ) { size in
                            ForEach(board.pins) { pin in
                                StaticPinView(pin: pin, boardSize: size)
                            }
                        } overlay: {
                        }
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .scaleEffect(scale, anchor: .topLeading)
                    }
                    // Trims the board's own shadow and glow, leaving just the board.
                    .clipShape(RoundedRectangle(cornerRadius: BoardMetrics.cornerRadius * scale, style: .continuous))
            }
            .aspectRatio(canvasSize.width / canvasSize.height, contentMode: .fit)
            .environment(\.boardLightingPaused, true)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 1) {
                Text(board.name.isEmpty ? "Untitled Board" : board.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(board.pins.count == 1 ? "1 pin" : "\(board.pins.count) pins")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
    }
}
