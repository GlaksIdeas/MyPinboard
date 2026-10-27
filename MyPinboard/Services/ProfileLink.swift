import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// How profiles are written to files, in a form other platforms can read: standard ISO 8601 dates and
/// sorted keys. Reading also accepts the older numeric dates, so nothing saved earlier is lost.
/// The format is described in docs/profile-format.md.
nonisolated enum ProfileCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
            let text = try container.decode(String.self)
            guard let date = ISO8601DateFormatter().date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(text)")
            }
            return date
        }
        return decoder
    }
}

/// A link that carries someone's name card: enough to add them as a friend when AirDrop isn't an option.
///
/// A link with no server behind it can't hold a whole profile, because pin photos make profiles far too
/// large. So it carries only a name, handle, bio, and a tiny photo. Boards arrive when they share the
/// full profile file. The shape is `pinboard://friend?v=1&id=…&name=…&handle=…&bio=…&avatar=…`; a website
/// can later serve the same path and query over https, and the app will read it unchanged.
nonisolated enum ProfileLink {
    static let scheme = "pinboard"
    static let host = "friend"
    static let currentVersion = 1

    /// Largest tiny photo, in bytes, that's allowed into a link. Bigger photos are left out.
    private static let maxAvatarBytes = 2500

    static func url(for profile: ProfileSnapshot) -> URL? {
        var items = [
            URLQueryItem(name: "v", value: String(currentVersion)),
            URLQueryItem(name: "id", value: profile.id.uuidString),
            URLQueryItem(name: "name", value: profile.displayName),
            URLQueryItem(name: "handle", value: profile.handle)
        ]
        if !profile.bio.isEmpty {
            items.append(URLQueryItem(name: "bio", value: profile.bio))
        }
        if let avatar = profile.avatarData,
           let tiny = ImageDownscaler.jpegData(from: avatar, maxDimension: 56, quality: 0.5),
           tiny.count <= maxAvatarBytes {
            items.append(URLQueryItem(name: "avatar", value: base64URL(tiny)))
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = items
        return components.url
    }

    /// Reads a name card from a link. Returns nil if it isn't a Pinboard friend link.
    static func card(from url: URL) -> ProfileSnapshot? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }

        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        guard let idText = value("id"), let id = UUID(uuidString: idText) else { return nil }
        let name = value("name") ?? ""
        let handle = value("handle") ?? ""
        // A link with neither a name nor a handle doesn't say who it is.
        guard !name.isEmpty || !handle.isEmpty else { return nil }

        return ProfileSnapshot(
            id: id,
            displayName: name,
            handle: handle,
            bio: value("bio") ?? "",
            avatarData: value("avatar").flatMap(data(fromBase64URL:))
        )
    }

    /// Finds a link in pasted text, which may have spaces or other words around it.
    static func card(fromPastedText text: String) -> ProfileSnapshot? {
        let candidates = text.split(whereSeparator: \.isWhitespace).map(String.init)
        for candidate in candidates {
            if let url = URL(string: candidate), let card = card(from: url) {
                return card
            }
        }
        return nil
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func data(fromBase64URL text: String) -> Data? {
        var base64 = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 += "="
        }
        return Data(base64Encoded: base64)
    }
}

/// Puts text on the system clipboard.
@MainActor
enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
