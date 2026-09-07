import Foundation

struct DunnoUserProfile: Codable, Equatable {
    var onboardingComplete = false
    var roles: [String] = []
    var interests: [String] = []
    var goals: [String] = []

    static let empty = DunnoUserProfile()

    private enum CodingKeys: String, CodingKey {
        case onboardingComplete, roles, interests, goals
    }

    /// Early builds are evolving quickly. Decode each field independently so adding or
    /// renaming one optional preference never throws away the user's whole profile.
    init(
        onboardingComplete: Bool = false,
        roles: [String] = [],
        interests: [String] = [],
        goals: [String] = []
    ) {
        self.onboardingComplete = onboardingComplete
        self.roles = roles
        self.interests = interests
        self.goals = goals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboardingComplete = try container.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? false
        roles = try container.decodeIfPresent([String].self, forKey: .roles) ?? []
        interests = try container.decodeIfPresent([String].self, forKey: .interests) ?? []
        goals = try container.decodeIfPresent([String].self, forKey: .goals) ?? []
    }
}

nonisolated struct ActivityInteractionState: Codable, Equatable, Sendable {
    var isSaved = false
    var isCompleted = false
    var notForMe = 0
    var timesShown = 0
    var lastShown: Date?
    var savedAt: Date?
    var completedAt: Date?
    var timesStarted = 0
    var timesCompleted = 0
    var saveLearningSignals = 0
    var completionFeedback: Int?
    var note: String?

    init(
        isSaved: Bool = false,
        isCompleted: Bool = false,
        notForMe: Int = 0,
        timesShown: Int = 0,
        lastShown: Date? = nil,
        savedAt: Date? = nil,
        completedAt: Date? = nil,
        timesStarted: Int = 0,
        timesCompleted: Int = 0,
        saveLearningSignals: Int = 0,
        completionFeedback: Int? = nil,
        note: String? = nil
    ) {
        self.isSaved = isSaved
        self.isCompleted = isCompleted
        self.notForMe = notForMe
        self.timesShown = timesShown
        self.lastShown = lastShown
        self.savedAt = savedAt
        self.completedAt = completedAt
        self.timesStarted = timesStarted
        self.timesCompleted = timesCompleted
        self.saveLearningSignals = saveLearningSignals
        self.completionFeedback = completionFeedback
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case isSaved, isCompleted, notForMe, timesShown
        case lastShown, savedAt, completedAt
        case timesStarted, timesCompleted, saveLearningSignals, completionFeedback, note
    }

    /// Keep early-build data readable as Dunno's interaction model evolves. Missing
    /// fields use safe defaults instead of invalidating the entire interaction store.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSaved = try container.decodeIfPresent(Bool.self, forKey: .isSaved) ?? false
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        notForMe = try container.decodeIfPresent(Int.self, forKey: .notForMe) ?? 0
        timesShown = try container.decodeIfPresent(Int.self, forKey: .timesShown) ?? 0
        lastShown = try container.decodeIfPresent(Date.self, forKey: .lastShown)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        timesStarted = try container.decodeIfPresent(Int.self, forKey: .timesStarted) ?? 0
        timesCompleted = try container.decodeIfPresent(Int.self, forKey: .timesCompleted) ?? 0
        saveLearningSignals = try container.decodeIfPresent(Int.self, forKey: .saveLearningSignals) ?? 0
        completionFeedback = try container.decodeIfPresent(Int.self, forKey: .completionFeedback)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}
