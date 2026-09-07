import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

struct DunnoSearchConstraints {
    var maxMinutes: Int?
    var social: DunnoSocial?
    var context: DunnoContext?
    var preferredCategories: Set<DunnoCategory> = []
    var energyCeiling: Int?
    var tokens: [String] = []

    init(query: String) {
        let normalized = query.lowercased()

        if let match = normalized.range(of: #"(?:under|less than|within|max|up to)\s+(\d{1,3})\s*(?:min|minute|minutes)?"#, options: .regularExpression) {
            let chunk = String(normalized[match])
            maxMinutes = chunk.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first
        }

        if normalized.contains("girlfriend") || normalized.contains("boyfriend") || normalized.contains("partner") || normalized.contains("date") {
            social = .partner
        } else if normalized.contains("friend") {
            social = .friend
        } else if normalized.contains("family") {
            social = .family
        } else if normalized.contains("group") || normalized.contains("people") {
            social = .group
        } else if normalized.contains("alone") || normalized.contains("myself") || normalized.contains("solo") {
            social = .solo
        }

        if normalized.contains("at home") || normalized.contains("inside") || normalized.contains("indoors") || normalized.contains("don't leave") || normalized.contains("dont leave") {
            context = .home
        } else if normalized.contains("outside") || normalized.contains("outdoors") {
            context = .outside
        } else if normalized.contains("phone") {
            context = .phone
        } else if normalized.contains("computer") || normalized.contains("laptop") {
            context = .computer
        }

        let categorySignals: [(DunnoCategory, [String])] = [
            (.create, ["creative", "create", "draw", "art", "make", "write"]),
            (.tech, ["tech", "computer", "coding", "internet", "phone"]),
            (.explore, ["explore", "outside", "go somewhere", "adventure", "walk"]),
            (.learn, ["learn", "study", "read", "knowledge"]),
            (.relax, ["relax", "chill", "cozy", "tired", "calm"]),
            (.active, ["active", "exercise", "move", "workout", "sport"]),
            (.social, ["social", "friends", "people", "together"]),
            (.food, ["food", "cook", "bake", "eat", "snack"]),
            (.play, ["play", "game", "fun"]),
            (.productive, ["useful", "productive", "clean", "organize", "fix"])
        ]
        for (category, signals) in categorySignals where signals.contains(where: normalized.contains) {
            preferredCategories.insert(category)
        }

        if normalized.contains("low energy") || normalized.contains("tired") || normalized.contains("lazy") || normalized.contains("relax") || normalized.contains("chill") {
            energyCeiling = 1
        }

        let stopWords: Set<String> = ["something", "things", "thing", "to", "do", "when", "i", "im", "i'm", "me", "my", "a", "an", "the", "with", "for", "and", "or", "that", "under", "less", "than", "within", "minutes", "minute", "min"]
        tokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopWords.contains($0) && Int($0) == nil }
    }

    var hasStructuredConstraint: Bool {
        maxMinutes != nil || social != nil || context != nil || energyCeiling != nil || !preferredCategories.isEmpty
    }

    func allows(_ activity: DunnoActivity) -> Bool {
        if let maxMinutes, activity.minMinutes > maxMinutes { return false }
        if let social, !activity.social.contains(.any), !activity.social.contains(social) { return false }
        if let context, !activity.contexts.contains(.anywhere), !activity.contexts.contains(context) { return false }
        if let energyCeiling, activity.energy.level > energyCeiling { return false }
        return true
    }
}

enum DunnoSearchEngine {
    private static let synonyms: [String: Set<String>] = [
        "creative": ["art", "draw", "paint", "write", "make", "craft", "photo", "design", "build"],
        "relax": ["chill", "cozy", "calm", "quiet", "rest", "read", "music"],
        "fun": ["play", "game", "challenge", "random", "silly", "explore"],
        "outside": ["outdoor", "park", "walk", "trail", "bike", "nature", "sunset"],
        "date": ["partner", "together", "coffee", "dessert", "walk", "food", "movie"],
        "friend": ["together", "group", "social", "challenge", "game"],
        "quick": ["short", "tiny", "mini", "fast"],
        "productive": ["useful", "organize", "clean", "fix", "plan"],
        "learn": ["read", "research", "practice", "study", "skill"],
        "food": ["cook", "bake", "snack", "meal", "drink", "cafe"]
    ]

    static func ranked(
        query: String,
        activities: [DunnoActivity],
        baseScore: (DunnoActivity) -> Double,
        maxResults: Int = 120
    ) -> [DunnoActivity] {
        let constraints = DunnoSearchConstraints(query: query)
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        // Search used to run the full personalization score for every activity on every
        // keystroke. First do the cheap text/constraint pass, then personalize only a
        // bounded shortlist. That keeps Explore responsive even as the catalog grows.
        let preliminary: [(activity: DunnoActivity, lexicalScore: Double)] = activities
            .filter(constraints.allows)
            .compactMap { activity in
                let title = activity.title.lowercased()
                let searchable = ([
                    activity.title,
                    activity.hook,
                    activity.description,
                    activity.category.rawValue
                ] + activity.tags + activity.goals)
                    .joined(separator: " ")
                    .lowercased()

                var lexicalScore = 0.0
                if searchable.localizedStandardContains(normalized) { lexicalScore += 15 }
                if title.localizedStandardContains(normalized) { lexicalScore += 12 }
                if constraints.preferredCategories.contains(activity.category) { lexicalScore += 7 }

                for token in constraints.tokens {
                    if title.contains(token) {
                        lexicalScore += 5.5
                    } else if searchable.contains(token) {
                        lexicalScore += 2.4
                    }

                    for synonym in synonyms[token] ?? [] where searchable.contains(synonym) {
                        lexicalScore += 1.25
                    }
                }

                if let maxMinutes = constraints.maxMinutes {
                    let distance = max(0, maxMinutes - activity.minMinutes)
                    lexicalScore += max(0, 3.0 - Double(distance) / 15.0)
                }

                if lexicalScore <= 0, constraints.hasStructuredConstraint {
                    lexicalScore = 0.75
                }

                guard lexicalScore > 0 else { return nil }
                return (activity, lexicalScore)
            }

        let shortlistLimit = min(preliminary.count, max(maxResults * 2, 160))
        let shortlist = preliminary
            .sorted { lhs, rhs in
                if lhs.lexicalScore == rhs.lexicalScore { return lhs.activity.title < rhs.activity.title }
                return lhs.lexicalScore > rhs.lexicalScore
            }
            .prefix(shortlistLimit)

        return shortlist
            .map { candidate in
                (candidate.activity, candidate.lexicalScore + baseScore(candidate.activity) * 0.04)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0.title < rhs.0.title }
                return lhs.1 > rhs.1
            }
            .prefix(maxResults)
            .map(\.0)
    }
}

enum DunnoSpotlightIndexer {
    static let domainIdentifier = "com.codearc.dunno.activities"
    static let identifierPrefix = "dunno.activity."

    private static let indexedCatalogVersion = 1
    private static let indexedCatalogVersionKey = "dunno.spotlight.catalogVersion"

    static func indexActivitiesIfNeeded(_ activities: [DunnoActivity]) {
        guard UserDefaults.standard.integer(forKey: indexedCatalogVersionKey) != indexedCatalogVersion else { return }

        indexActivities(activities) { succeeded in
            guard succeeded else { return }
            UserDefaults.standard.set(indexedCatalogVersion, forKey: indexedCatalogVersionKey)
        }
    }

    static func indexActivities(_ activities: [DunnoActivity], completion: ((Bool) -> Void)? = nil) {
        let items = activities.map { activity -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = activity.title
            attributes.displayName = activity.title
            attributes.contentDescription = activity.hook
            attributes.keywords = Array(Set(
                [activity.category.rawValue, activity.durationLabel, activity.energy.shortLabel] +
                activity.tags + activity.goals + activity.contexts.map(\.rawValue) + activity.social.map(\.rawValue)
            ))
            attributes.contentURL = DunnoShareLink.url(for: activity, mode: .share)

            return CSSearchableItem(
                uniqueIdentifier: identifierPrefix + activity.id,
                domainIdentifier: domainIdentifier,
                attributeSet: attributes
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            #if DEBUG
            if let error { print("Dunno Spotlight indexing failed: \(error)") }
            #endif
            completion?(error == nil)
        }
    }

    static func activityID(from searchableIdentifier: String) -> String? {
        guard searchableIdentifier.hasPrefix(identifierPrefix) else { return nil }
        return String(searchableIdentifier.dropFirst(identifierPrefix.count))
    }
}
