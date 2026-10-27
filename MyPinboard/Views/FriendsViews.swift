import SwiftUI
import SwiftData

extension EnvironmentValues {
    /// Starts adding a friend from a profile file. Set by the app's root view.
    @Entry var importFriend: () -> Void = {}
}

/// The people you've added, with your Top Friends featured. There is no feed and nobody is suggested:
/// this only ever shows people you chose.
struct FriendsSection: View {
    @Query(sort: \Friend.dateAdded) private var friends: [Friend]
    @Environment(\.importFriend) private var importFriend

    private var topFriends: [Friend] {
        friends
            .filter { $0.topRank != nil }
            .sorted { ($0.topRank ?? 0) < ($1.topRank ?? 0) }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Friends")
                    .font(.title3.bold())
                    .fontDesign(.rounded)
                Spacer()
                Button("Add Friend", systemImage: "person.badge.plus", action: importFriend)
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }

            if friends.isEmpty {
                emptyState
            } else {
                if !topFriends.isEmpty {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(topFriends) { friend in
                            NavigationLink(value: friend) {
                                FriendTile(friend: friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                NavigationLink {
                    FriendsListView()
                } label: {
                    HStack {
                        Text("All Friends")
                        Spacer()
                        Text(friends.count.formatted())
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No friends yet")
                .font(.headline)
            Text("There's no feed or suggestions here. Ask a friend to AirDrop you their profile, then tap Add Friend when it arrives.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct FriendTile: View {
    let friend: Friend

    var body: some View {
        VStack(spacing: 6) {
            AvatarView(data: friend.avatarData, name: friend.displayName, size: 64)
            Text(friend.displayName.isEmpty ? "@\(friend.handle)" : friend.displayName)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Everyone you've added, with swipe actions to feature or remove them.
struct FriendsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.importFriend) private var importFriend
    @Query(sort: \Friend.displayName) private var friends: [Friend]

    var body: some View {
        List {
            ForEach(friends) { friend in
                NavigationLink(value: friend) {
                    HStack(spacing: 12) {
                        AvatarView(data: friend.avatarData, name: friend.displayName, size: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(friend.displayName.isEmpty ? "Unnamed" : friend.displayName)
                                .font(.headline)
                            if !friend.handle.isEmpty {
                                Text("@\(friend.handle)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if friend.topRank != nil {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Top friend")
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    let isTop = friend.topRank != nil
                    Button(isTop ? "Unfeature" : "Feature", systemImage: isTop ? "star.slash" : "star") {
                        FriendImporter.setTopFriend(friend, !isTop, among: friends)
                    }
                    .tint(.yellow)
                }
            }
            .onDelete { offsets in
                let removed = offsets.map { friends[$0] }
                for friend in removed {
                    FriendImporter.setTopFriend(friend, false, among: friends)
                    modelContext.delete(friend)
                }
            }
        }
        .navigationTitle("All Friends")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Friend", systemImage: "person.badge.plus", action: importFriend)
            }
        }
        .overlay {
            if friends.isEmpty {
                ContentUnavailableView(
                    "No Friends Yet",
                    systemImage: "person.2",
                    description: Text("Open a profile someone shared with you to add them.")
                )
            }
        }
    }
}

#Preview("Friend profile") {
    PreviewFriendProfile()
        .modelContainer(previewContainer())
}

#Preview("Friend's board") {
    PreviewFriendBoard()
        .modelContainer(previewContainer())
}

/// Opens the first sample friend's profile.
private struct PreviewFriendProfile: View {
    @Query private var friends: [Friend]

    var body: some View {
        NavigationStack {
            if let friend = friends.first {
                FriendProfileView(friend: friend)
            }
        }
    }
}

/// Opens the first sample friend's first board, read-only.
private struct PreviewFriendBoard: View {
    @Query private var friends: [Friend]

    var body: some View {
        NavigationStack {
            if let board = friends.first?.profile?.boards.first {
                PublicBoardView(board: board, credit: "@ollie_finch")
            }
        }
    }
}

/// A friend's profile, read-only, from the copy saved when you added them.
struct FriendProfileView: View {
    let friend: Friend

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var friends: [Friend]
    @State private var isConfirmingRemoval = false

    private var isTopFull: Bool {
        friends.filter { $0.topRank != nil }.count >= FriendImporter.topFriendLimit
    }

    var body: some View {
        ScrollView {
            if let profile = friend.profile {
                ProfileContent(
                    profile: profile,
                    credit: profile.handle.isEmpty ? nil : "@\(profile.handle)"
                ) {
                } footer: {
                }
            } else {
                ContentUnavailableView(
                    "Profile Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("The saved copy of this profile couldn't be read. Ask them to share it again.")
                )
            }
        }
        .collapsingBannerTitle(friend.displayName.isEmpty ? "Friend" : friend.displayName, bannerHeight: 90)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    let isTop = friend.topRank != nil
                    Button(
                        isTop ? "Remove from Top Friends" : "Add to Top Friends",
                        systemImage: isTop ? "star.slash" : "star"
                    ) {
                        FriendImporter.setTopFriend(friend, !isTop, among: friends)
                    }
                    .disabled(!isTop && isTopFull)

                    Button("Remove Friend", systemImage: "person.badge.minus", role: .destructive) {
                        isConfirmingRemoval = true
                    }
                }
            }
        }
        .confirmationDialog("Remove this friend?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
            Button("Remove Friend", role: .destructive) {
                FriendImporter.setTopFriend(friend, false, among: friends)
                modelContext.delete(friend)
                dismiss()
            }
        } message: {
            Text("You can add them again any time they share their profile with you.")
        }
    }
}
