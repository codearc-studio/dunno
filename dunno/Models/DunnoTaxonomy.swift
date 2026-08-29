import Foundation

struct DunnoChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String?

    init(_ id: String, _ title: String, _ systemImage: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

enum DunnoTaxonomy {
    static let roles: [DunnoChoice] = [
        .init("student", "Student", "graduationcap.fill"),
        .init("developer", "Developer", "chevron.left.forwardslash.chevron.right"),
        .init("designer", "Designer", "paintbrush.pointed.fill"),
        .init("creative", "Creative", "sparkles"),
        .init("gamer", "Gamer", "gamecontroller.fill"),
        .init("music-lover", "Music lover", "music.note"),
        .init("movies-tv", "Movies & TV", "tv.fill"),
        .init("reader", "Reader", "book.fill"),
        .init("active", "Active", "figure.run"),
        .init("outdoors", "Outdoors", "leaf.fill"),
        .init("food-person", "Food person", "fork.knife"),
        .init("tech-person", "Tech person", "laptopcomputer"),
        .init("maker", "Maker", "hammer.fill"),
        .init("social", "Social", "person.2.fill"),
        .init("traveler", "Traveler", "airplane"),
        .init("parent", "Parent", "figure.2.and.child.holdinghands")
    ]

    // Interests intentionally describe subject matter instead of repeating the role screen.
    static let interests: [DunnoChoice] = [
        .init("building-making", "Building & making", "hammer.fill"),
        .init("random-learning", "Random learning", "brain.head.profile"),
        .init("photography", "Photography", "camera.fill"),
        .init("cooking-baking", "Cooking & baking", "frying.pan.fill"),
        .init("music", "Music", "music.note"),
        .init("movies-tv", "Movies & TV", "film.fill"),
        .init("reading", "Reading", "book.fill"),
        .init("art-design", "Art & design", "paintpalette.fill"),
        .init("games", "Games", "gamecontroller.fill"),
        .init("sports-fitness", "Sports & fitness", "figure.run"),
        .init("outdoors", "Outdoors", "leaf.fill"),
        .init("tech", "Tech", "laptopcomputer"),
        .init("internet-rabbit-holes", "Internet rabbit holes", "safari.fill"),
        .init("diy-home", "DIY & home", "wrench.and.screwdriver.fill"),
        .init("food-cafes", "Food & cafes", "cup.and.saucer.fill"),
        .init("shopping-style", "Shopping & style", "bag.fill"),
        .init("writing", "Writing", "pencil.line"),
        .init("local-exploring", "Local exploring", "map.fill"),
        .init("cars", "Cars", "car.fill"),
        .init("pets", "Pets", "pawprint.fill"),
        .init("plants-gardening", "Plants & gardening", "leaf.fill"),
        .init("organizing", "Organizing", "square.grid.3x3.fill"),
        .init("relaxing", "Relaxing & cozy", "moon.stars.fill")
    ]

    static let goals: [DunnoChoice] = [
        .init("easy", "Easy stuff when I'm tired", "moon.stars.fill"),
        .init("make", "Make something", "hammer.fill"),
        .init("learn", "Learn something", "book.fill"),
        .init("discover", "Discover something", "safari.fill"),
        .init("useful", "Actually useful things", "checkmark.circle.fill"),
        .init("go-somewhere", "Go somewhere", "location.fill"),
        .init("people", "Things to do with people", "person.2.fill"),
        .init("new", "New things to try", "sparkles"),
        .init("surprise", "Surprise me", "wand.and.stars")
    ]

    static let onboardingHeaderSymbols: [String] = [
        "person.2.fill",
        "square.grid.2x2.fill",
        "sparkles",
        "rectangle.stack.fill"
    ]

    static func aliases(for selection: String) -> Set<String> {
        let normalized = normalize(selection)
        return normalizedAliasMap[normalized] ?? [normalized]
    }
 
    static func activitySignals(_ activity: DunnoActivity) -> Set<String> {
        var output: Set<String> = []

        for tag in activity.tags {
            output.insert(normalize(tag))
        }

        output.insert(normalize(activity.category.rawValue))

        for goal in activity.goals {
            output.insert(normalize(goal))
        }

        return output
    }

    static func migrateInterests(_ values: [String]) -> [String] {
        var output: [String] = []
        for value in values {
            let migrated = legacyInterestMap[value] ?? value
            if !output.contains(migrated) { output.append(migrated) }
        }
        return output
    }

    nonisolated static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let aliasMap: [String: [String]] = [
        "student": ["student"],
        "developer": ["developer", "coding", "tech", "building things"],
        "designer": ["designer", "design", "art", "creative"],
        "creative": ["creative", "art", "design", "writing", "photography"],
        "gamer": ["gamer", "gaming", "games"],
        "music lover": ["music lover", "music"],
        "movies and tv": ["movies and tv", "movies & tv"],
        "reader": ["reader", "reading"],
        "active": ["active", "fitness", "sports"],
        "outdoors": ["outdoors", "explorer"],
        "food person": ["food person", "food", "cooking"],
        "tech person": ["tech person", "tech", "coding", "internet"],
        "maker": ["maker", "building things", "diy"],
        "social": ["social"],
        "traveler": ["traveler", "explorer", "exploring"],
        "parent": ["parent", "family"],

        "building and making": ["building things", "maker", "diy", "creative"],
        "random learning": ["learning random stuff", "student", "reader"],
        "photography": ["photography"],
        "cooking and baking": ["cooking", "food", "food person"],
        "music": ["music", "music lover"],
        "reading": ["reading", "reader"],
        "art and design": ["art", "design", "designer", "creative"],
        "games": ["gaming", "gamer", "games"],
        "sports and fitness": ["fitness", "active", "sports"],
        "tech": ["tech", "tech person", "coding", "developer"],
        "internet rabbit holes": ["internet", "learning random stuff"],
        "diy and home": ["diy", "maker", "organizing", "parent"],
        "food and cafes": ["food", "food person", "shopping", "explorer"],
        "shopping and style": ["shopping", "design", "creative"],
        "writing": ["writing", "writer", "creative"],
        "local exploring": ["explorer", "exploring", "traveler", "shopping"],
        "cars": ["cars", "car", "automotive"],
        "pets": ["pets", "pet", "dog", "cat"],
        "plants and gardening": ["plants", "gardening", "outdoors", "diy"],
        "organizing": ["organizing"],
        "relaxing and cozy": ["relaxation", "music", "reader"]
    ]

    /// Alias sets are immutable taxonomy data. Normalizing them for every activity score
    /// multiplied the same string work thousands of times during each recommendation pass.
    private static let normalizedAliasMap: [String: Set<String>] = aliasMap.mapValues {
        Set($0.map(normalize))
    }

    private static let legacyInterestMap: [String: String] = [
        "Building things": "Building & making",
        "Learning random stuff": "Random learning",
        "Coding": "Tech",
        "Design": "Art & design",
        "Gaming": "Games",
        "Reading": "Reading",
        "Art": "Art & design",
        "Cooking": "Cooking & baking",
        "Food": "Food & cafes",
        "Fitness": "Sports & fitness",
        "Internet": "Internet rabbit holes",
        "Shopping": "Shopping & style",
        "Exploring": "Local exploring",
        "Relaxation": "Relaxing & cozy",
        "DIY": "DIY & home"
    ]
}
