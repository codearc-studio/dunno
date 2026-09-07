import AppIntents
import Foundation

nonisolated struct DunnoSharedSuggestion: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let hook: String
    let category: String
    let symbol: String
    let duration: String
}

nonisolated struct DunnoSharedCurrentActivity: Codable, Hashable, Sendable {
    let activity: DunnoSharedSuggestion
    let startedAt: Date
    let timerEndAt: Date?

    init(activity: DunnoSharedSuggestion, startedAt: Date, timerEndAt: Date? = nil) {
        self.activity = activity
        self.startedAt = startedAt
        self.timerEndAt = timerEndAt
    }
}

nonisolated enum DunnoSharedSystemState {
    static let appGroupIdentifier = "group.com.codearc.dunno"
    static let widgetKind = "DunnoSuggestionWidget"

    private static let suggestionsKey = "dunno.shared.widget.suggestions.v1"
    private static let suggestionIndexKey = "dunno.shared.widget.index"
    private static let currentActivityKey = "dunno.shared.currentActivity.v1"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func suggestions() -> [DunnoSharedSuggestion] {
        guard let data = defaults?.data(forKey: suggestionsKey) else { return [] }
        return (try? JSONDecoder().decode([DunnoSharedSuggestion].self, from: data)) ?? []
    }

    static func replaceSuggestions(_ suggestions: [DunnoSharedSuggestion]) {
        guard let defaults, let data = try? JSONEncoder().encode(suggestions) else { return }
        defaults.set(data, forKey: suggestionsKey)

        let currentIndex = defaults.integer(forKey: suggestionIndexKey)
        if suggestions.isEmpty || currentIndex >= suggestions.count {
            defaults.set(0, forKey: suggestionIndexKey)
        }
    }

    static func currentSuggestion() -> DunnoSharedSuggestion? {
        let suggestions = suggestions()
        guard !suggestions.isEmpty else { return nil }
        let index = min(max(defaults?.integer(forKey: suggestionIndexKey) ?? 0, 0), suggestions.count - 1)
        return suggestions[index]
    }

    @discardableResult
    static func advanceSuggestion() -> DunnoSharedSuggestion? {
        let suggestions = suggestions()
        guard !suggestions.isEmpty, let defaults else { return nil }
        let current = min(max(defaults.integer(forKey: suggestionIndexKey), 0), suggestions.count - 1)
        let next = (current + 1) % suggestions.count
        defaults.set(next, forKey: suggestionIndexKey)
        return suggestions[next]
    }

    static func setCurrentActivity(_ activity: DunnoSharedSuggestion, startedAt: Date = Date(), timerEndAt: Date? = nil) {
        guard let defaults,
              let data = try? JSONEncoder().encode(DunnoSharedCurrentActivity(activity: activity, startedAt: startedAt, timerEndAt: timerEndAt)) else { return }
        defaults.set(data, forKey: currentActivityKey)
    }

    static func currentActivity() -> DunnoSharedCurrentActivity? {
        guard let data = defaults?.data(forKey: currentActivityKey) else { return nil }
        return try? JSONDecoder().decode(DunnoSharedCurrentActivity.self, from: data)
    }

    static func clearCurrentActivity() {
        defaults?.removeObject(forKey: currentActivityKey)
    }
}

nonisolated enum DunnoOpenDestination: String, AppEnum {
    case forYou

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dunno screen")
    static let caseDisplayRepresentations: [DunnoOpenDestination: DisplayRepresentation] = [
        .forYou: DisplayRepresentation(title: "For You")
    ]
}

struct OpenDunnoIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Dunno"

    @Parameter(title: "Destination")
    var target: DunnoOpenDestination

    init() {
        target = .forYou
    }

    init(target: DunnoOpenDestination) {
        self.target = target
    }
}

#if canImport(ActivityKit)
import ActivityKit

nonisolated struct DunnoActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        let title: String
        let category: String
        let symbol: String
        let duration: String
        let timerEndAt: Date?
    }

    let id: String
    let title: String
    let category: String
    let symbol: String
    let duration: String
    let startedAt: Date
}
#endif
