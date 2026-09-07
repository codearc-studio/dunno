import Foundation

enum DunnoShareMode: String, CaseIterable, Codable, Identifiable {
    case share
    case together

    var id: String { rawValue }

    var title: String {
        switch self {
        case .share: "share this"
        case .together: "do this with me"
        }
    }

    var symbol: String {
        switch self {
        case .share: "square.and.arrow.up"
        case .together: "person.2.fill"
        }
    }

    var cardKicker: String {
        switch self {
        case .share: "dunno picked this"
        case .together: "do this with me?"
        }
    }
}

struct DunnoIncomingShare: Identifiable, Hashable {
    let activity: DunnoActivity
    let mode: DunnoShareMode

    var id: String { "\(activity.id)|\(mode.rawValue)" }
}

enum DunnoShareLink {
    static let host = "dunno.codearc.studio"
    static let sharePath = "/share"

    static func url(for activity: DunnoActivity, mode: DunnoShareMode) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = sharePath
        components.queryItems = [
            URLQueryItem(name: "activity", value: activity.id),
            URLQueryItem(name: "mode", value: mode.rawValue),
            // These are display-only fallbacks for people who don't have Dunno installed.
            // The app trusts the activity ID and reads the canonical copy from its catalog.
            URLQueryItem(name: "title", value: activity.title),
            URLQueryItem(name: "hook", value: activity.hook),
            URLQueryItem(name: "duration", value: activity.durationLabel)
        ]

        return components.url ?? URL(string: "https://\(host)/share")!
    }

    static func parse(_ url: URL) -> (activityID: String, mode: DunnoShareMode)? {
        let scheme = url.scheme?.lowercased()
        let isUniversalLink = scheme == "https"
            && url.host?.lowercased() == host
            && (url.path == sharePath || url.path == "\(sharePath)/")
        let isCustomScheme = scheme == "dunno"
            && (url.host?.lowercased() == "share" || url.path == sharePath || url.path == "\(sharePath)/")

        guard isUniversalLink || isCustomScheme else { return nil }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let activityID = components.queryItems?.first(where: { $0.name == "activity" })?.value,
              !activityID.isEmpty else { return nil }

        let rawMode = components.queryItems?.first(where: { $0.name == "mode" })?.value
        let mode = rawMode.flatMap(DunnoShareMode.init(rawValue:)) ?? .share
        return (activityID, mode)
    }
}
