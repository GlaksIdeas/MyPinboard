import Foundation
import SwiftData

/// The person using this app: how they appear to others.
@Model
final class Profile {
    /// Stable identity across exports and devices.
    var uuid: UUID = UUID()
    var displayName: String = ""
    /// Lowercase handle without the "@".
    var handle: String = ""
    var bio: String = ""
    @Attribute(.externalStorage) var avatarData: Data?
    var dateJoined: Date = Date.now

    init() {}
}

/// Someone you've added to your network. There is no feed or recommendation of people:
/// you only see the profiles you've chosen to save.
@Model
final class Friend {
    /// Matches the saved profile's id, so adding the same person again updates them.
    var profileID: UUID = UUID()
    var displayName: String = ""
    var handle: String = ""
    var dateAdded: Date = Date.now
    /// Position in Top Friends (1...8), or nil when not featured.
    var topRank: Int?
    /// Kept separately so lists can show a face without decoding the whole profile.
    @Attribute(.externalStorage) var avatarData: Data?
    /// The profile as it was when added, encoded as JSON.
    @Attribute(.externalStorage) var profileData: Data?

    init(profile: ProfileSnapshot) {
        update(with: profile)
    }

    /// Replaces the saved profile with a newer copy.
    func update(with profile: ProfileSnapshot) {
        profileID = profile.id
        displayName = profile.displayName
        handle = profile.handle
        avatarData = profile.avatarData
        profileData = try? ProfileCoding.encoder.encode(profile)
    }

    /// The saved profile, decoded.
    var profile: ProfileSnapshot? {
        guard let profileData else { return nil }
        return try? ProfileCoding.decoder.decode(ProfileSnapshot.self, from: profileData)
    }
}
