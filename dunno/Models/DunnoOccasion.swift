import Foundation

struct DunnoOccasion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let searchSignals: [String]
    let preferredCategories: Set<DunnoCategory>
    let preferredSocial: Set<DunnoSocial>
    let preferredContexts: Set<DunnoContext>

    static let all: [DunnoOccasion] = [
        DunnoOccasion(
            id: "date-night",
            title: "date night",
            subtitle: "For when the hardest part is deciding what to do together.",
            symbol: "heart.fill",
            searchSignals: ["date", "coffee", "cafe", "dessert", "walk", "food", "movie", "game", "photo", "explore", "together"],
            preferredCategories: [.food, .explore, .social, .play, .create],
            preferredSocial: [.partner, .friend, .any],
            preferredContexts: [.out, .outside, .home, .anywhere]
        ),
        DunnoOccasion(
            id: "with-friends",
            title: "with friends",
            subtitle: "Ideas that are better when somebody else is in on it.",
            symbol: "person.2.fill",
            searchSignals: ["friend", "group", "challenge", "game", "together", "cook", "food", "walk", "photo", "competition"],
            preferredCategories: [.social, .play, .food, .active, .explore],
            preferredSocial: [.friend, .group, .any],
            preferredContexts: [.anywhere, .out, .home, .outside]
        ),
        DunnoOccasion(
            id: "rainy-day",
            title: "rainy day",
            subtitle: "Things that still sound good when going outside absolutely does not.",
            symbol: "cloud.rain.fill",
            searchSignals: ["cozy", "inside", "indoor", "movie", "bake", "cook", "read", "draw", "game", "organize", "music"],
            preferredCategories: [.relax, .create, .food, .play, .tech, .learn],
            preferredSocial: [.any, .solo, .friend, .partner, .family],
            preferredContexts: [.home, .computer, .phone, .anywhere]
        ),
        DunnoOccasion(
            id: "late-night",
            title: "late night",
            subtitle: "Low-stakes ideas for when the day should probably be over, but isn't.",
            symbol: "moon.stars.fill",
            searchSignals: ["night", "midnight", "late", "cozy", "music", "movie", "snack", "game", "read", "journal", "stars"],
            preferredCategories: [.relax, .play, .food, .create, .tech],
            preferredSocial: [.any, .solo, .friend, .partner],
            preferredContexts: [.home, .phone, .computer, .anywhere]
        ),
        DunnoOccasion(
            id: "road-trip",
            title: "road trip",
            subtitle: "For the passenger seat, the next stop, or the break you actually need.",
            symbol: "car.fill",
            searchSignals: ["road", "car", "drive", "trip", "travel", "playlist", "photo", "stop", "snack", "map", "scenic"],
            preferredCategories: [.explore, .social, .food, .play, .tech],
            preferredSocial: [.any, .friend, .partner, .family, .group],
            preferredContexts: [.out, .phone, .anywhere]
        ),
        DunnoOccasion(
            id: "stuck-inside",
            title: "stuck inside",
            subtitle: "A better answer than scrolling because leaving isn't happening.",
            symbol: "house.fill",
            searchSignals: ["home", "inside", "room", "desk", "cook", "bake", "make", "learn", "game", "movie", "clean", "organize"],
            preferredCategories: [.create, .relax, .play, .food, .tech, .productive],
            preferredSocial: [.any, .solo, .friend, .partner, .family],
            preferredContexts: [.home, .computer, .phone]
        ),
        DunnoOccasion(
            id: "summer-night",
            title: "summer night",
            subtitle: "Warm-air, stay-out-a-little-longer kind of ideas.",
            symbol: "sparkles",
            searchSignals: ["sunset", "night", "outside", "walk", "ice cream", "photo", "stars", "park", "picnic", "bike", "summer"],
            preferredCategories: [.explore, .social, .active, .food, .create],
            preferredSocial: [.any, .friend, .partner, .group],
            preferredContexts: [.outside, .out, .anywhere]
        ),
        DunnoOccasion(
            id: "family-time",
            title: "with family",
            subtitle: "Stuff that can actually work across a room full of different moods.",
            symbol: "figure.2.and.child.holdinghands",
            searchSignals: ["family", "together", "game", "cook", "walk", "movie", "challenge", "photo", "food", "outside"],
            preferredCategories: [.social, .play, .food, .explore, .create],
            preferredSocial: [.family, .group, .any],
            preferredContexts: [.anywhere, .home, .out, .outside]
        )
    ]

    func score(_ activity: DunnoActivity) -> Double {
        let text = ([activity.title, activity.hook, activity.description] + activity.tags + activity.goals)
            .joined(separator: " ")
            .lowercased()

        var score = 0.0
        if preferredCategories.contains(activity.category) { score += 3.2 }
        if !Set(activity.social).isDisjoint(with: preferredSocial) || activity.social.contains(.any) { score += 2.2 }
        if !Set(activity.contexts).isDisjoint(with: preferredContexts) || activity.contexts.contains(.anywhere) { score += 1.6 }

        for signal in searchSignals where text.contains(signal) {
            score += 1.15
        }

        if id == "rainy-day" && (activity.contexts.contains(.outside) || activity.contexts.contains(.out)) && !activity.contexts.contains(.home) {
            score -= 3.5
        }
        if id == "stuck-inside" && activity.contexts.contains(.outside) && !activity.contexts.contains(.home) {
            score -= 4.0
        }
        return score
    }

    func matches(_ activity: DunnoActivity) -> Bool {
        score(activity) >= 4.0
    }
}
