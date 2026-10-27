import Foundation
import SwiftData

enum FriendImportError: LocalizedError {
    case unreadable
    case isSelf

    var errorDescription: String? {
        switch self {
        case .unreadable: "That isn't a Pinboard profile or friend link, or it's damaged."
        case .isSelf: "That's your own profile."
        }
    }
}

/// Adds people to your network from profile files they've shared. There's no search or suggestions:
/// you only ever see people you've deliberately added.
@MainActor
enum FriendImporter {
    static let topFriendLimit = 8

    /// Reads a shared profile file, without adding anyone. Show it to the person to confirm first.
    static func readProfile(from url: URL, in context: ModelContext) throws -> ProfileSnapshot {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        guard let profile = try? ProfileCoding.decoder.decode(ProfileSnapshot.self, from: data) else {
            throw FriendImportError.unreadable
        }

        try checkNotSelf(profile, in: context)
        return profile
    }

    /// Reads a name card from a link, without adding anyone.
    static func readLink(_ url: URL, in context: ModelContext) throws -> ProfileSnapshot {
        guard let card = ProfileLink.card(from: url) else {
            throw FriendImportError.unreadable
        }
        try checkNotSelf(card, in: context)
        return card
    }

    /// Reads a name card from pasted text, which may have other words around the link.
    static func readPastedText(_ text: String, in context: ModelContext) throws -> ProfileSnapshot {
        guard let card = ProfileLink.card(fromPastedText: text) else {
            throw FriendImportError.unreadable
        }
        try checkNotSelf(card, in: context)
        return card
    }

    private static func checkNotSelf(_ profile: ProfileSnapshot, in context: ModelContext) throws {
        let own = try context.fetch(FetchDescriptor<Profile>())
        if own.contains(where: { $0.uuid == profile.id }) {
            throw FriendImportError.isSelf
        }
    }

    /// Whether this person is already in your friends, so a new copy would refresh them.
    static func isAlreadyFriend(_ profile: ProfileSnapshot, in context: ModelContext) -> Bool {
        let friends = (try? context.fetch(FetchDescriptor<Friend>())) ?? []
        return friends.contains { $0.profileID == profile.id }
    }

    /// Saves a profile as a friend, or refreshes them if you've already added them.
    @discardableResult
    static func add(_ profile: ProfileSnapshot, into context: ModelContext) throws -> Friend {
        let friends = try context.fetch(FetchDescriptor<Friend>())
        if let existing = friends.first(where: { $0.profileID == profile.id }) {
            if profile.cardOnly == true, var full = existing.profile, full.cardOnly != true {
                // A name card only refreshes who they are; it must not wipe out the boards you already have.
                full.displayName = profile.displayName
                full.handle = profile.handle
                full.bio = profile.bio
                full.avatarData = profile.avatarData ?? full.avatarData
                existing.update(with: full)
            } else {
                existing.update(with: profile)
            }
            return existing
        }

        let friend = Friend(profile: profile)
        // New friends join Top Friends until it's full.
        let rankedCount = friends.filter { $0.topRank != nil }.count
        if rankedCount < topFriendLimit {
            friend.topRank = rankedCount + 1
        }
        context.insert(friend)
        return friend
    }

    /// Adds or removes a friend from Top Friends, keeping the ranks 1, 2, 3… with no gaps.
    /// Does nothing when adding to a full Top Friends.
    static func setTopFriend(_ friend: Friend, _ isTop: Bool, among friends: [Friend]) {
        var ranked = friends
            .filter { $0.topRank != nil && $0.profileID != friend.profileID }
            .sorted { ($0.topRank ?? 0) < ($1.topRank ?? 0) }

        if isTop {
            guard ranked.count < topFriendLimit else { return }
            ranked.append(friend)
        } else {
            friend.topRank = nil
        }

        for (index, member) in ranked.enumerated() {
            member.topRank = index + 1
        }
    }
}
