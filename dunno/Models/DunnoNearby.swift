import Foundation

enum DunnoNearbyKind: String, CaseIterable, Hashable, Identifiable {
    case bookstore
    case cafe
    case park
    case trail
    case library
    case museum
    case thriftStore
    case recordStore
    case farmersMarket
    case bakery
    case publicGarden
    case gardenCenter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bookstore: "bookstore"
        case .cafe: "cafe"
        case .park: "park"
        case .trail: "trail"
        case .library: "library"
        case .museum: "museum or gallery"
        case .thriftStore: "thrift store"
        case .recordStore: "record store"
        case .farmersMarket: "farmers market"
        case .bakery: "bakery"
        case .publicGarden: "public garden"
        case .gardenCenter: "garden center"
        }
    }

    var pluralLabel: String {
        switch self {
        case .bookstore: "bookstores"
        case .cafe: "cafes"
        case .park: "parks"
        case .trail: "trails"
        case .library: "libraries"
        case .museum: "museums & galleries"
        case .thriftStore: "thrift stores"
        case .recordStore: "record stores"
        case .farmersMarket: "farmers markets"
        case .bakery: "bakeries"
        case .publicGarden: "public gardens"
        case .gardenCenter: "garden centers"
        }
    }

    var searchQuery: String {
        switch self {
        case .bookstore: "bookstore"
        case .cafe: "coffee shop"
        case .park: "park"
        case .trail: "hiking trail"
        case .library: "library"
        case .museum: "museum"
        case .thriftStore: "thrift store"
        case .recordStore: "record store"
        case .farmersMarket: "farmers market"
        case .bakery: "bakery"
        case .publicGarden: "botanical garden"
        case .gardenCenter: "garden center"
        }
    }

    var symbol: String {
        switch self {
        case .bookstore: "books.vertical.fill"
        case .cafe: "cup.and.saucer.fill"
        case .park: "tree.fill"
        case .trail: "figure.hiking"
        case .library: "building.columns.fill"
        case .museum: "building.columns"
        case .thriftStore: "hanger"
        case .recordStore: "record.circle"
        case .farmersMarket: "basket.fill"
        case .bakery: "birthday.cake.fill"
        case .publicGarden: "leaf.fill"
        case .gardenCenter: "leaf.circle.fill"
        }
    }

    var searchRadius: Double {
        switch self {
        case .cafe, .bakery: 6_000
        case .bookstore, .park, .library: 9_000
        case .thriftStore, .gardenCenter, .publicGarden: 12_000
        case .recordStore, .museum: 16_000
        case .trail, .farmersMarket: 20_000
        }
    }

    /// Common place types are prefetched after an opted-in foreground location refresh.
    /// Less common kinds are searched only when an activity that needs them is opened.
    static let commonKinds: [DunnoNearbyKind] = [
        .park,
        .cafe,
        .library,
        .bookstore,
        .trail,
        .museum
    ]

    static func infer(for activity: DunnoActivity) -> DunnoNearbyKind? {
        guard activity.contexts.contains(.out) || activity.contexts.contains(.outside) else {
            return nil
        }

        // Stay conservative: nearby should appear only when the activity itself explicitly
        // names a place type, not because a supporting sentence happens to mention one.
        let text = activity.title.lowercased()

        if containsAny(text, ["thrift store", "thrift-store", "thrift challenge", "thrift mission"]) {
            return .thriftStore
        }
        if containsAny(text, ["record store"]) {
            return .recordStore
        }
        if containsAny(text, ["farmers market", "farmer's market", "farmer’s market"]) {
            return .farmersMarket
        }
        if containsAny(text, ["bookstore", "book shop"]) {
            return .bookstore
        }
        if containsAny(text, ["library branch", "library shelf", "library you", "free library"]) {
            return .library
        }
        if containsAny(text, ["museum", "gallery"]) {
            return .museum
        }
        if containsAny(text, ["coffee shop", "cafe", "café", "coffee run"]) {
            return .cafe
        }
        if containsAny(text, ["bakery"]) {
            return .bakery
        }
        if containsAny(text, ["garden center"]) {
            return .gardenCenter
        }
        if containsAny(text, ["public garden", "hidden garden"]) {
            return .publicGarden
        }
        if containsAny(text, ["trail", "hike a short local"]) {
            return .trail
        }
        if containsAny(text, ["park", "green space"]) {
            return .park
        }

        return nil
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}
