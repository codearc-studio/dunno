import Foundation
import Dispatch
import Combine

@MainActor
final class DunnoStore: ObservableObject {
    @Published private(set) var profile: DunnoUserProfile
    @Published private(set) var interactions: [String: ActivityInteractionState]
    @Published private(set) var calibrationAffinities: [String: Double]
    @Published private(set) var behaviorAffinities: [String: Double]
    @Published private(set) var currentActivityID: String?
    @Published private(set) var currentActivityStartedAt: Date?
    @Published private(set) var currentActivityTimerEndAt: Date?
    @Published private(set) var collections: [DunnoCollection]
    @Published var externalActivity: DunnoActivity?
    @Published private(set) var neverRepeatCompleted: Bool
    @Published private(set) var onboardingStep: Int
    @Published private(set) var reviewRequestPending: Bool
    @Published private(set) var completionFeedbackActivityID: String?
    @Published var incomingShare: DunnoIncomingShare?

    // Session-only context. These describe what is true right now, not who the user is.
    @Published var filters = DunnoFilters() {
        didSet {
            filtersUpdatedAt = filters.isActive ? Date() : nil
        }
    }
    @Published private(set) var shuffleSeed = 0

    let activities: [DunnoActivity] = ActivityCatalog.all

    private let defaults: UserDefaults
    private let persistenceWriter: DunnoPersistenceWriter
    private let profileKey = "dunno.profile.v1"
    private let interactionKey = "dunno.interactions.v1"
    private let calibrationKey = "dunno.calibration.v1"
    private let behaviorAffinityKey = "dunno.behaviorAffinities.v1"
    private let currentActivityIDKey = "dunno.currentActivity.id"
    private let currentActivityDateKey = "dunno.currentActivity.startedAt"
    private let currentActivityTimerEndKey = "dunno.currentActivity.timerEndAt"
    private let collectionsKey = "dunno.collections.v1"
    private let neverRepeatCompletedKey = "dunno.settings.neverRepeatCompleted"
    private let onboardingStepKey = "dunno.onboarding.step"
    private let reviewQualifiedCompletionCountKey = "dunno.review.qualifiedCompletionCount"
    private let reviewRequestDateKey = "dunno.review.lastRequestDate"
    private let reviewRequestVersionKey = "dunno.review.lastRequestVersion"
    private let completionFeedbackPendingKey = "dunno.feedback.pendingActivityID"

    private let rightNowLifetime: TimeInterval = 4 * 60 * 60
    private let reviewRequestCooldown: TimeInterval = 180 * 24 * 60 * 60
    private let reviewMinimumCompletions = 3
    private var filtersUpdatedAt: Date?
    private var exposureSaveTask: Task<Void, Never>?
    private var activityMetadataCache: [String: ActivityMetadata] = [:]
    private lazy var activityLookup: [String: DunnoActivity] = Dictionary(
        uniqueKeysWithValues: activities.map { ($0.id, $0) }
    )
    private var savedActivitiesCache: [DunnoActivity]?
    private var completedActivitiesCache: [DunnoActivity]?
    private var hiddenActivitiesCache: [DunnoActivity]?
    private var hiddenFeedbackCache: [HiddenFeedbackSignal]?
    private var nearbyAvailableKinds: Set<DunnoNearbyKind> = []

    private struct HiddenFeedbackSignal {
        let category: DunnoCategory
        let signals: Set<String>
    }

    private struct ActivityMetadata {
        let signals: Set<String>
        let normalizedGoals: Set<String>
        let preferredDayparts: Set<DunnoDaypart>
        let strictDaypart: Bool
        let nearbyKind: DunnoNearbyKind?
        let calibrationCategoryKey: String
        let calibrationTagKeys: [String]
        let calibrationGoalKeys: [String]
        let jitterSalt: Int
        let searchableText: String
    }

    init(
        defaults: UserDefaults = .standard,
        runDiagnostics: Bool = ProcessInfo.processInfo.arguments.contains("-DunnoRunDiagnostics")
    ) {
        self.defaults = defaults
        self.persistenceWriter = DunnoPersistenceWriter(defaults: defaults)

        var loadedProfile = Self.decode(DunnoUserProfile.self, from: defaults.data(forKey: profileKey)) ?? .empty
        loadedProfile.roles = Self.sanitizedSelections(
            loadedProfile.roles,
            allowed: DunnoTaxonomy.roles.map(\.title)
        )
        loadedProfile.interests = Self.sanitizedSelections(
            DunnoTaxonomy.migrateInterests(loadedProfile.interests),
            allowed: DunnoTaxonomy.interests.map(\.title)
        )
        loadedProfile.goals = Self.sanitizedSelections(
            loadedProfile.goals,
            allowed: DunnoTaxonomy.goals.map(\.title)
        )
        self.profile = loadedProfile

        self.interactions = Self.decode([String: ActivityInteractionState].self, from: defaults.data(forKey: interactionKey)) ?? [:]
        self.calibrationAffinities = Self.decode([String: Double].self, from: defaults.data(forKey: calibrationKey)) ?? [:]
        self.behaviorAffinities = Self.decode([String: Double].self, from: defaults.data(forKey: behaviorAffinityKey)) ?? [:]
        self.currentActivityID = defaults.string(forKey: currentActivityIDKey)
        self.currentActivityStartedAt = defaults.object(forKey: currentActivityDateKey) as? Date
        self.currentActivityTimerEndAt = defaults.object(forKey: currentActivityTimerEndKey) as? Date
        self.collections = Self.decode([DunnoCollection].self, from: defaults.data(forKey: collectionsKey)) ?? []
        self.externalActivity = nil
        self.neverRepeatCompleted = defaults.bool(forKey: neverRepeatCompletedKey)
        self.onboardingStep = loadedProfile.onboardingComplete
            ? 0
            : min(max(defaults.integer(forKey: onboardingStepKey), 0), 4)
        self.reviewRequestPending = false
        self.completionFeedbackActivityID = defaults.string(forKey: completionFeedbackPendingKey)
        self.incomingShare = nil

        sanitizePersistedState()
        expireCurrentActivityIfNeeded()

        if runDiagnostics {
            DunnoDiagnostics.validateCatalog(activities)
            #if DEBUG
            Task { @MainActor in
                await Task.yield()
                DunnoReleaseChecks.runOnce()
            }
            #endif
        }

        saveProfile()
    }

    // MARK: - Library state

    var savedActivities: [DunnoActivity] {
        if let savedActivitiesCache { return savedActivitiesCache }
        let result = activities
            .filter {
                let state = interactions[$0.id]
                return state?.isSaved == true && state?.isCompleted != true && state?.notForMe == 0
            }
            .sorted { interactionDate(for: $0, kind: .saved) > interactionDate(for: $1, kind: .saved) }
        savedActivitiesCache = result
        return result
    }

    var completedActivities: [DunnoActivity] {
        if let completedActivitiesCache { return completedActivitiesCache }
        // Did It is history, so an idea stays here even if the user later asks Dunno
        // to stop suggesting similar things.
        let result = activities
            .filter { interactions[$0.id]?.isCompleted == true }
            .sorted { interactionDate(for: $0, kind: .completed) > interactionDate(for: $1, kind: .completed) }
        completedActivitiesCache = result
        return result
    }

    var hiddenActivities: [DunnoActivity] {
        if let hiddenActivitiesCache { return hiddenActivitiesCache }
        let result = activities
            .filter { isNotInterested($0) }
            .sorted {
                (interactions[$0.id]?.lastShown ?? .distantPast) >
                (interactions[$1.id]?.lastShown ?? .distantPast)
            }
        hiddenActivitiesCache = result
        return result
    }

    var currentActivity: DunnoActivity? {
        guard let currentActivityID else { return nil }
        return activityLookup[currentActivityID]
    }

    func activity(id: String) -> DunnoActivity? {
        activityLookup[id]
    }

    func presentActivity(id: String) {
        externalActivity = activity(id: id)
    }

    // MARK: - Collections + private notes

    func activities(in collection: DunnoCollection) -> [DunnoActivity] {
        let ids = Set(collection.activityIDs)
        return savedActivities.filter { ids.contains($0.id) }
    }

    @discardableResult
    func createCollection(named rawName: String) -> DunnoCollection? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let collection = DunnoCollection(name: name)
        collections.append(collection)
        saveCollections()
        return collection
    }

    func renameCollection(_ collection: DunnoCollection, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        collections[index].name = name
        saveCollections()
    }

    func deleteCollection(_ collection: DunnoCollection) {
        collections.removeAll { $0.id == collection.id }
        saveCollections()
    }

    func isInCollection(_ activity: DunnoActivity, collection: DunnoCollection) -> Bool {
        collections.first(where: { $0.id == collection.id })?.activityIDs.contains(activity.id) == true
    }

    func setActivity(_ activity: DunnoActivity, in collection: DunnoCollection, included: Bool) {
        guard let index = collections.firstIndex(where: { $0.id == collection.id }) else { return }

        if included {
            var state = interactions[activity.id] ?? ActivityInteractionState()
            if !state.isCompleted && !state.isSaved {
                state.isSaved = true
                state.savedAt = Date()
                interactions[activity.id] = state
                invalidateLibraryCaches()
                saveInteractions()
            }
            if !collections[index].activityIDs.contains(activity.id) {
                collections[index].activityIDs.append(activity.id)
            }
        } else {
            collections[index].activityIDs.removeAll { $0 == activity.id }
        }
        saveCollections()
    }

    func note(for activity: DunnoActivity) -> String {
        interactions[activity.id]?.note ?? ""
    }

    func setNote(_ rawNote: String, for activity: DunnoActivity) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        let trimmed = rawNote.trimmingCharacters(in: .whitespacesAndNewlines)
        state.note = trimmed.isEmpty ? nil : String(trimmed.prefix(1500))
        interactions[activity.id] = state
        saveInteractions()
    }

    // MARK: - Profile + onboarding

    func toggleRole(_ value: String) {
        profile.roles.toggle(value)
        saveProfile()
        shuffleSeed += 1
    }

    func toggleInterest(_ value: String) {
        profile.interests.toggle(value)
        saveProfile()
        shuffleSeed += 1
    }

    func toggleGoal(_ value: String) {
        profile.goals.toggle(value)
        saveProfile()
        shuffleSeed += 1
    }

    /// Preferences are edited as a local draft in the picker and committed once when the
    /// user leaves. That keeps rapid taps responsive and avoids reranking the whole catalog
    /// for every individual pill selection.
    func updatePreferences(roles: [String], interests: [String], goals: [String]) {
        let nextRoles = Self.sanitizedSelections(roles, allowed: DunnoTaxonomy.roles.map(\.title))
        let nextInterests = Self.sanitizedSelections(
            DunnoTaxonomy.migrateInterests(interests),
            allowed: DunnoTaxonomy.interests.map(\.title)
        )
        let nextGoals = Self.sanitizedSelections(goals, allowed: DunnoTaxonomy.goals.map(\.title))

        guard profile.roles != nextRoles ||
              profile.interests != nextInterests ||
              profile.goals != nextGoals else { return }

        profile.roles = nextRoles
        profile.interests = nextInterests
        profile.goals = nextGoals
        saveProfile()
        shuffleSeed += 1
    }

    func setOnboardingStep(_ step: Int) {
        onboardingStep = min(max(step, 0), 4)
        if onboardingStep == 0 {
            defaults.removeObject(forKey: onboardingStepKey)
        } else {
            defaults.set(onboardingStep, forKey: onboardingStepKey)
        }
    }

    func finishOnboarding() {
        profile.onboardingComplete = true
        setOnboardingStep(0)
        saveProfile()
        shuffleSeed += 1
    }

    /// Redoing onboarding keeps the choices visible for editing, but starts the
    /// calibration pass fresh so repeated onboarding cannot stack training weight.
    func resetOnboarding() {
        profile.onboardingComplete = false
        resetCalibration()
        setOnboardingStep(1)
        saveProfile()
        shuffleSeed += 1
    }

    func resetCalibration() {
        calibrationAffinities = [:]
        saveCalibration()
    }

    /// Clears only behavior-derived taste learning. Saved ideas, Did It history,
    /// onboarding choices, and explicit hidden suggestions are preserved.
    func resetBehaviorLearning() {
        persistenceWriter.flush()
        behaviorAffinities = [:]
        completionFeedbackActivityID = nil
        defaults.removeObject(forKey: behaviorAffinityKey)
        defaults.removeObject(forKey: completionFeedbackPendingKey)

        for id in Array(interactions.keys) {
            guard var state = interactions[id] else { continue }
            state.timesStarted = 0
            state.timesCompleted = 0
            state.saveLearningSignals = 0
            state.completionFeedback = nil
            interactions[id] = state
        }

        saveInteractions()
        shuffleSeed += 1
    }

    func resetAll() {
        persistenceWriter.flush()
        profile = .empty
        interactions = [:]
        invalidateHiddenFeedbackCache()
        invalidateLibraryCaches()
        calibrationAffinities = [:]
        behaviorAffinities = [:]
        filters = DunnoFilters()
        currentActivityID = nil
        currentActivityStartedAt = nil
        currentActivityTimerEndAt = nil
        collections = []
        externalActivity = nil
        neverRepeatCompleted = false
        onboardingStep = 0
        reviewRequestPending = false
        completionFeedbackActivityID = nil

        defaults.removeObject(forKey: profileKey)
        defaults.removeObject(forKey: interactionKey)
        defaults.removeObject(forKey: calibrationKey)
        defaults.removeObject(forKey: behaviorAffinityKey)
        defaults.removeObject(forKey: currentActivityIDKey)
        defaults.removeObject(forKey: currentActivityDateKey)
        defaults.removeObject(forKey: currentActivityTimerEndKey)
        defaults.removeObject(forKey: collectionsKey)
        defaults.removeObject(forKey: neverRepeatCompletedKey)
        defaults.removeObject(forKey: onboardingStepKey)
        defaults.removeObject(forKey: reviewQualifiedCompletionCountKey)
        defaults.removeObject(forKey: completionFeedbackPendingKey)
        DunnoSystemSurfaceBridge.clearCurrentActivity()
        shuffleSeed += 1
    }

    // MARK: - Activity interactions

    func recordShown(_ activity: DunnoActivity) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        state.timesShown += 1
        state.lastShown = Date()
        interactions[activity.id] = state
        scheduleInteractionSave()
    }

    /// A normal left swipe only means "not right now." It does not train Dunno.
    func skipForNow(_ activity: DunnoActivity) {
        // Queue movement is owned by HomeView. Keeping this side-effect free prevents
        // the recommendation queue from rebuilding while a swipe animation is running.
    }

    /// A normal right swipe means "I want to do this now," not "I permanently like this."
    func chooseForNow(_ activity: DunnoActivity) {
        beginCurrentActivity(activity)
    }

    // Compatibility shims for older call sites.
    func skip(_ activity: DunnoActivity) { skipForNow(activity) }
    func like(_ activity: DunnoActivity) { chooseForNow(activity) }

    /// Calibration is deliberately separate from ordinary swipes. It gives Dunno a small
    /// starting bias, then gets out of the way.
    func recordCalibration(_ activity: DunnoActivity, positive: Bool) {
        let direction = positive ? 1.0 : -1.0
        adjustAffinity("category:\(DunnoTaxonomy.normalize(activity.category.rawValue))", by: direction * 1.6)

        for tag in activity.tags.prefix(5) {
            adjustAffinity("tag:\(DunnoTaxonomy.normalize(tag))", by: direction * 0.45)
        }

        for goal in activity.goals.prefix(3) {
            adjustAffinity("goal:\(DunnoTaxonomy.normalize(goal))", by: direction * 0.65)
        }

        saveCalibration()
    }

    func toggleSaved(_ activity: DunnoActivity) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        guard !state.isCompleted else { return }

        state.isSaved.toggle()
        state.savedAt = state.isSaved ? Date() : nil

        if state.isSaved, state.saveLearningSignals < 2 {
            state.saveLearningSignals += 1
            applyBehaviorSignal(for: activity, strength: 0.45)
        }

        interactions[activity.id] = state
        invalidateLibraryCaches()
        if !state.isSaved { removeFromAllCollections(activity) }
        saveInteractions()
    }

    func complete(_ activity: DunnoActivity) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        let wasCompleted = state.isCompleted
        let wasCurrentActivity = currentActivityID == activity.id
        state.isCompleted = true
        state.completedAt = Date()
        if !wasCompleted {
            state.timesCompleted += 1
            if state.timesCompleted <= 3 {
                applyBehaviorSignal(for: activity, strength: 1.0)
            }
        }
        // Once it is done, Did It is the canonical place for it. Avoid showing the same
        // activity in both halves of Library.
        state.isSaved = false
        state.savedAt = nil
        interactions[activity.id] = state
        invalidateLibraryCaches()
        removeFromAllCollections(activity)

        if currentActivityID == activity.id {
            clearCurrentActivity()
        }

        saveInteractions()
        if !wasCompleted && wasCurrentActivity {
            let qualifiedCount = defaults.integer(forKey: reviewQualifiedCompletionCountKey) + 1
            defaults.set(qualifiedCount, forKey: reviewQualifiedCompletionCountKey)
            scheduleCompletionFeedbackIfAppropriate(for: activity, completionCount: qualifiedCount)
            refreshReviewRequestEligibility()
        }
        shuffleSeed += 1
    }

    /// Removes an item from the Did It history without changing anything else about it.
    func removeCompleted(_ activity: DunnoActivity) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        state.isCompleted = false
        state.completedAt = nil
        interactions[activity.id] = state
        invalidateLibraryCaches()
        saveInteractions()
        shuffleSeed += 1
    }

    /// Cancels the current activity without marking it complete.
    func cancelCurrentActivity() {
        clearCurrentActivity()
    }

    func setNeverRepeatCompleted(_ enabled: Bool) {
        neverRepeatCompleted = enabled
        defaults.set(enabled, forKey: neverRepeatCompletedKey)
        shuffleSeed += 1
    }

    /// Explicit long-term feedback. This is intentionally stronger than a normal left swipe:
    /// the exact idea disappears and similar categories/tags get a modest negative bias.
    func showLessLikeThis(_ activity: DunnoActivity) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        state.notForMe = max(1, state.notForMe + 1)
        state.isSaved = false
        state.savedAt = nil
        interactions[activity.id] = state
        invalidateHiddenFeedbackCache()
        invalidateLibraryCaches()
        removeFromAllCollections(activity)

        if currentActivityID == activity.id {
            clearCurrentActivity()
        }

        saveInteractions()
    }

    /// Gives users a way back from an accidental long-term preference action.
    func restoreSuggestion(_ activity: DunnoActivity, refresh: Bool = true) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        guard state.notForMe > 0 else { return }
        state.notForMe = 0
        interactions[activity.id] = state
        invalidateHiddenFeedbackCache()

        saveInteractions()
        if refresh { shuffleSeed += 1 }
    }

    func restoreAllHiddenSuggestions() {
        let hidden = hiddenActivities
        guard !hidden.isEmpty else { return }

        for activity in hidden {
            var state = interactions[activity.id] ?? ActivityInteractionState()
            state.notForMe = 0
            interactions[activity.id] = state
        }
        invalidateHiddenFeedbackCache()

        saveInteractions()
        shuffleSeed += 1
    }

    // Compatibility for older call sites.
    func markNotForMe(_ activity: DunnoActivity) {
        showLessLikeThis(activity)
        shuffleSeed += 1
    }

    func isSaved(_ activity: DunnoActivity) -> Bool {
        interactions[activity.id]?.isSaved == true
    }

    func isCompleted(_ activity: DunnoActivity) -> Bool {
        interactions[activity.id]?.isCompleted == true
    }

    func isNotInterested(_ activity: DunnoActivity) -> Bool {
        (interactions[activity.id]?.notForMe ?? 0) > 0
    }

    // MARK: - Learning feedback

    var completionFeedbackActivity: DunnoActivity? {
        guard let completionFeedbackActivityID else { return nil }
        return activityLookup[completionFeedbackActivityID]
    }

    /// Completion already teaches Dunno a little. This optional feedback is a stronger
    /// signal and stays fully on-device with the rest of the preference model.
    func submitCompletionFeedback(for activity: DunnoActivity, positive: Bool) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        let nextValue = positive ? 1 : -1
        let previousValue = state.completionFeedback ?? 0

        guard previousValue != nextValue else {
            dismissCompletionFeedback()
            return
        }

        // Combine any replacement + new feedback into one learning update. Publishing each
        // individual tag/category mutation made every EnvironmentObject observer redraw
        // several times on one tap.
        var netStrength = positive ? 1.8 : -1.5
        if previousValue != 0 {
            netStrength += previousValue > 0 ? -1.8 : 1.5
        }

        state.completionFeedback = nextValue
        interactions[activity.id] = state
        applyBehaviorSignal(for: activity, strength: netStrength)

        // Feedback affects future ranking. There is no need to rebuild the visible card
        // queue underneath the feedback dismissal animation. Persist after the interaction
        // frame instead of blocking the tap with a full interactions JSON encode.
        scheduleInteractionSave()
        dismissCompletionFeedback()
    }

    func dismissCompletionFeedback() {
        completionFeedbackActivityID = nil
        defaults.removeObject(forKey: completionFeedbackPendingKey)
    }

    private func scheduleCompletionFeedbackIfAppropriate(for activity: DunnoActivity, completionCount: Int) {
        guard interactions[activity.id]?.completionFeedback == nil else { return }

        // Ask after the user has seen real value, then only occasionally. This keeps the
        // prompt useful as training data instead of turning every completion into a survey.
        let shouldAsk = completionCount == 2 || (completionCount >= 5 && (completionCount - 5).isMultiple(of: 4))
        guard shouldAsk else { return }

        completionFeedbackActivityID = activity.id
        defaults.set(activity.id, forKey: completionFeedbackPendingKey)
    }

    // MARK: - App Store review

    /// Dunno only asks after the user has actually gotten value from the app. The view
    /// decides when the UI moment is calm enough to call StoreKit.
    func refreshReviewRequestEligibility() {
        let qualifiedCount = defaults.integer(forKey: reviewQualifiedCompletionCountKey)

        guard qualifiedCount >= reviewMinimumCompletions else {
            reviewRequestPending = false
            return
        }

        let currentVersion = Self.currentAppVersion
        let lastVersion = defaults.string(forKey: reviewRequestVersionKey)
        if lastVersion == currentVersion {
            reviewRequestPending = false
            return
        }

        if let lastRequestDate = defaults.object(forKey: reviewRequestDateKey) as? Date,
           Date().timeIntervalSince(lastRequestDate) < reviewRequestCooldown {
            reviewRequestPending = false
            return
        }

        reviewRequestPending = true
    }

    func markReviewRequestAttempted() {
        reviewRequestPending = false
        defaults.set(Date(), forKey: reviewRequestDateKey)
        defaults.set(Self.currentAppVersion, forKey: reviewRequestVersionKey)
    }

    private static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }


    // MARK: - Shared activity links

    func handleIncomingShareURL(_ url: URL) {
        guard let link = DunnoShareLink.parse(url),
              let activity = activityLookup[link.activityID] else { return }

        incomingShare = DunnoIncomingShare(activity: activity, mode: link.mode)
    }

    // MARK: - Doing Now

    func beginCurrentActivity(_ activity: DunnoActivity, startedAt: Date = Date()) {
        var state = interactions[activity.id] ?? ActivityInteractionState()
        state.timesStarted += 1
        if state.timesStarted <= 3 {
            applyBehaviorSignal(for: activity, strength: 0.25)
        }
        interactions[activity.id] = state
        saveInteractions()

        currentActivityID = activity.id
        currentActivityStartedAt = startedAt
        currentActivityTimerEndAt = nil
        defaults.set(activity.id, forKey: currentActivityIDKey)
        defaults.set(startedAt, forKey: currentActivityDateKey)
        defaults.removeObject(forKey: currentActivityTimerEndKey)
        DunnoSystemSurfaceBridge.mirrorCurrentActivity(activity, startedAt: startedAt, timerEndAt: nil)
    }

    func startCurrentActivityTimer(minutes: Int? = nil) {
        guard let activity = currentActivity, let startedAt = currentActivityStartedAt else { return }
        let suggested = max(5, minutes ?? min(max(activity.minMinutes, 10), 90))
        let target = Date().addingTimeInterval(TimeInterval(suggested * 60))
        currentActivityTimerEndAt = target
        defaults.set(target, forKey: currentActivityTimerEndKey)
        DunnoSystemSurfaceBridge.updateCurrentActivity(activity, startedAt: startedAt, timerEndAt: target)
    }

    func extendCurrentActivityTimer(by minutes: Int = 10) {
        guard let activity = currentActivity, let startedAt = currentActivityStartedAt else { return }
        let base = max(currentActivityTimerEndAt ?? Date(), Date())
        let target = base.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        currentActivityTimerEndAt = target
        defaults.set(target, forKey: currentActivityTimerEndKey)
        DunnoSystemSurfaceBridge.updateCurrentActivity(activity, startedAt: startedAt, timerEndAt: target)
    }

    func clearCurrentActivityTimer() {
        guard let activity = currentActivity, let startedAt = currentActivityStartedAt else { return }
        currentActivityTimerEndAt = nil
        defaults.removeObject(forKey: currentActivityTimerEndKey)
        DunnoSystemSurfaceBridge.updateCurrentActivity(activity, startedAt: startedAt, timerEndAt: nil)
    }

    func suggestedTimerMinutes(for activity: DunnoActivity) -> Int {
        max(5, min(activity.minMinutes, 90))
    }

    /// App Intents and widgets can update Dunno's persisted state while the app is being foregrounded.
    /// Pull that state into the live ObservableObject before displaying Doing Now.
    func syncCurrentActivityFromPersistence() {
        var adoptedWidgetStart = false

        if let shared = DunnoSystemSurfaceBridge.sharedCurrentActivity(),
           activities.contains(where: { $0.id == shared.activity.id }) {
            let localDate = defaults.object(forKey: currentActivityDateKey) as? Date
            if localDate == nil || shared.startedAt > (localDate ?? .distantPast) {
                defaults.set(shared.activity.id, forKey: currentActivityIDKey)
                defaults.set(shared.startedAt, forKey: currentActivityDateKey)
                if let timerEndAt = shared.timerEndAt {
                    defaults.set(timerEndAt, forKey: currentActivityTimerEndKey)
                } else {
                    defaults.removeObject(forKey: currentActivityTimerEndKey)
                }
                adoptedWidgetStart = true
            }
        }

        let persistedID = defaults.string(forKey: currentActivityIDKey)
        let persistedDate = defaults.object(forKey: currentActivityDateKey) as? Date
        let persistedTimerEnd = defaults.object(forKey: currentActivityTimerEndKey) as? Date
        guard persistedID != currentActivityID ||
              persistedDate != currentActivityStartedAt ||
              persistedTimerEnd != currentActivityTimerEndAt else { return }

        interactions = Self.decode(
            [String: ActivityInteractionState].self,
            from: defaults.data(forKey: interactionKey)
        ) ?? interactions
        invalidateHiddenFeedbackCache()
        invalidateLibraryCaches()
        behaviorAffinities = Self.decode(
            [String: Double].self,
            from: defaults.data(forKey: behaviorAffinityKey)
        ) ?? behaviorAffinities

        currentActivityID = persistedID
        currentActivityStartedAt = persistedDate
        currentActivityTimerEndAt = persistedTimerEnd
        sanitizePersistedState()
        expireCurrentActivityIfNeeded()

        if let activity = currentActivity, let startedAt = currentActivityStartedAt {
            if adoptedWidgetStart {
                var state = interactions[activity.id] ?? ActivityInteractionState()
                state.timesStarted += 1
                if state.timesStarted <= 3 {
                    applyBehaviorSignal(for: activity, strength: 0.25)
                }
                interactions[activity.id] = state
                saveInteractions()
            }

            DunnoSystemSurfaceBridge.mirrorCurrentActivity(activity, startedAt: startedAt, timerEndAt: currentActivityTimerEndAt)
        }

        shuffleSeed += 1
    }

    func repairCurrentSystemSurfacesIfNeeded() {
        guard let activity = currentActivity, let startedAt = currentActivityStartedAt else {
            DunnoSystemSurfaceBridge.clearCurrentActivity()
            return
        }
        DunnoSystemSurfaceBridge.repairCurrentActivityIfNeeded(
            activity,
            startedAt: startedAt,
            timerEndAt: currentActivityTimerEndAt
        )
    }

    func clearCurrentActivity() {
        currentActivityID = nil
        currentActivityStartedAt = nil
        currentActivityTimerEndAt = nil
        defaults.removeObject(forKey: currentActivityIDKey)
        defaults.removeObject(forKey: currentActivityDateKey)
        defaults.removeObject(forKey: currentActivityTimerEndKey)
        DunnoSystemSurfaceBridge.clearCurrentActivity()
    }

    func expireCurrentActivityIfNeeded() {
        guard let started = currentActivityStartedAt else {
            if currentActivityID != nil { clearCurrentActivity() }
            return
        }

        guard let activity = currentActivity else {
            clearCurrentActivity()
            return
        }

        // Short ideas should not stay pinned all day, while longer activities get more room.
        let activityLifetime = min(
            12 * 60 * 60,
            max(4 * 60 * 60, TimeInterval(activity.maxMinutes * 60 * 3))
        )

        if Date().timeIntervalSince(started) > activityLifetime {
            clearCurrentActivity()
        }
    }

    // MARK: - Right Now

    /// Nearby availability is session-only. Coordinates and place results live in the
    /// foreground-only location service and are never persisted into the recommendation store.
    func updateNearbyAvailability(_ kinds: Set<DunnoNearbyKind>) {
        guard nearbyAvailableKinds != kinds else { return }
        nearbyAvailableKinds = kinds
        shuffleSeed += 1
    }

    func expireFiltersIfNeeded() {
        guard filters.isActive, let filtersUpdatedAt else { return }
        if Date().timeIntervalSince(filtersUpdatedAt) > rightNowLifetime {
            filters = DunnoFilters()
        }
    }

    func shuffle() {
        shuffleSeed += 1
    }

    // MARK: - Recommendations

    private enum RecommendationLane {
        case strong
        case adjacent
        case wildcard
    }

    private struct RecommendationCandidate {
        let activity: DunnoActivity
        let score: Double
        let affinity: Double
        let novelty: Double
        let lane: RecommendationLane
    }

    private enum DurationBand: Int {
        case tiny
        case short
        case medium
        case long

        init(_ activity: DunnoActivity) {
            switch activity.maxMinutes {
            case ...15: self = .tiny
            case ...35: self = .short
            case ...75: self = .medium
            default: self = .long
            }
        }
    }

    func matchingCount(filters override: DunnoFilters? = nil) -> Int {
        availableActivities(filters: override ?? filters).count
    }

    /// Recommendation Engine v2 deliberately separates three jobs:
    /// 1. strict Right Now eligibility,
    /// 2. personal relevance,
    /// 3. queue composition/variety.
    ///
    /// That keeps a strong profile from becoming repetitive and keeps wildcard ideas
    /// genuinely exploratory without ever violating the user's current constraints.
    func recommendations(filters override: DunnoFilters? = nil, limit: Int? = nil) -> [DunnoActivity] {
        let activeFilters = override ?? filters
        let available = availableActivities(filters: activeFilters)
        guard !available.isEmpty else { return [] }

        let candidates = available.map { candidate(for: $0, filters: activeFilters) }
        return buildRecommendationQueue(from: candidates, limit: limit)
    }

    /// Public score is used by deliberate browsing surfaces such as Explore search.
    /// It represents general personal relevance without applying temporary Right Now
    /// constraints or queue-position diversity penalties.
    func score(_ activity: DunnoActivity) -> Double {
        personalizedScore(for: activity, filters: DunnoFilters())
    }

    func searchableText(for activity: DunnoActivity) -> String {
        metadata(for: activity).searchableText
    }

    private func candidate(for activity: DunnoActivity, filters: DunnoFilters) -> RecommendationCandidate {
        let affinity = preferenceAffinity(for: activity)
        let novelty = noveltyScore(for: activity)
        let score = personalizedScore(for: activity, filters: filters, preferenceAffinity: affinity)

        let hasPreferenceData = !profile.roles.isEmpty ||
            !profile.interests.isEmpty ||
            !profile.goals.isEmpty ||
            !calibrationAffinities.isEmpty ||
            !behaviorAffinities.isEmpty

        let lane: RecommendationLane
        if !hasPreferenceData {
            // Dunno should still be excellent before onboarding has much signal.
            lane = .strong
        } else if affinity >= 4.0 {
            lane = .strong
        } else if affinity >= 0.85 {
            lane = .adjacent
        } else {
            lane = .wildcard
        }

        return RecommendationCandidate(
            activity: activity,
            score: score,
            affinity: affinity,
            novelty: novelty,
            lane: lane
        )
    }

    private func personalizedScore(
        for activity: DunnoActivity,
        filters: DunnoFilters,
        preferenceAffinity cachedPreferenceAffinity: Double? = nil
    ) -> Double {
        var value = 24.0

        // Profile relevance intentionally saturates. Selecting five overlapping onboarding
        // choices should not make one category unbeatable forever.
        value += cachedPreferenceAffinity ?? preferenceAffinity(for: activity)
        value += calibrationScore(for: activity)
        value += behaviorScore(for: activity)
        value += feedbackScore(for: activity)
        value += daypartScore(for: activity)
        value += nearbyScore(for: activity)
        value += rightNowFitScore(for: activity, filters: filters)
        value += historyScore(for: activity)

        if currentActivityID == activity.id {
            value -= 100
        }

        // Stable seed-based jitter prevents ties from looking permanently sorted while
        // remaining deterministic until the user intentionally shuffles.
        value += deterministicJitter(for: activity, amplitude: 4.2)
        return value
    }

    private func preferenceAffinity(for activity: DunnoActivity) -> Double {
        let metadata = metadata(for: activity)
        let signals = metadata.signals
        var value = 0.0

        let roleMatches = profile.roles.reduce(into: 0) { count, role in
            if !signals.isDisjoint(with: DunnoTaxonomy.aliases(for: role)) { count += 1 }
        }
        if roleMatches > 0 {
            value += 3.8 + min(3.2, Double(roleMatches - 1) * 1.15)
        }

        let interestMatches = profile.interests.reduce(into: 0) { count, interest in
            if !signals.isDisjoint(with: DunnoTaxonomy.aliases(for: interest)) { count += 1 }
        }
        if interestMatches > 0 {
            value += 5.4 + min(6.0, Double(interestMatches - 1) * 1.7)
        }

        let goalMatches = profile.goals.reduce(into: 0) { count, goal in
            if metadata.normalizedGoals.contains(DunnoTaxonomy.normalize(goal)) { count += 1 }
        }
        if goalMatches > 0 {
            value += 4.6 + min(3.8, Double(goalMatches - 1) * 1.4)
        }

        return min(value, 20)
    }

    private func nearbyScore(for activity: DunnoActivity) -> Double {
        guard let kind = metadata(for: activity).nearbyKind,
              nearbyAvailableKinds.contains(kind) else { return 0 }

        // Nearby is a contextual tie-breaker, not a requirement. A confirmed real-world
        // match should make an idea more actionable without overwhelming learned taste.
        return 3.1
    }

    private func rightNowFitScore(for activity: DunnoActivity, filters: DunnoFilters) -> Double {
        var value = 0.0

        if let maxMinutes = filters.maxMinutes {
            // Eligibility already guarantees the activity fully fits. Among those results,
            // mildly favor ideas that make useful use of the available window rather than
            // always surfacing the shortest possible option.
            let utilization = Double(activity.maxMinutes) / Double(max(maxMinutes, 1))
            if utilization >= 0.55 { value += 2.0 }
            else if utilization >= 0.30 { value += 1.1 }
            else { value += 0.35 }
        }

        if let energy = filters.energy {
            let gap = energy.level - activity.energy.level
            switch gap {
            case 0: value += 2.4
            case 1: value += 1.2
            default: value += 0.35
            }
        }

        if let context = filters.context, context != .anywhere {
            if activity.contexts.contains(context) {
                value += 2.1
            } else if activity.contexts.contains(.anywhere) {
                value += 0.55
            }
        }

        if let social = filters.social, social != .any {
            if activity.social.contains(social) {
                value += 2.1
            } else if activity.social.contains(.any) {
                value += 0.45
            }
        }

        return value
    }

    private func historyScore(for activity: DunnoActivity) -> Double {
        guard let state = interactions[activity.id] else {
            return 4.0 // New ideas deserve a real chance.
        }

        var value = 0.0

        if state.timesShown == 0 {
            value += 4.0
        } else {
            value -= min(5.0, Double(state.timesShown) * 0.55)
        }

        if let lastShown = state.lastShown {
            let hours = Date().timeIntervalSince(lastShown) / 3600
            if hours < 6 { value -= 24 }
            else if hours < 12 { value -= 18 }
            else if hours < 24 { value -= 13 }
            else if hours < 72 { value -= 7 }
            else if hours < 168 { value -= 3 }
        }

        if state.isSaved {
            // Saved ideas remain discoverable, but For You should prioritize something fresh.
            value -= 3.0
            if let savedAt = state.savedAt {
                let hours = Date().timeIntervalSince(savedAt) / 3600
                if hours < 24 { value -= 7 }
                else if hours < 168 { value -= 3 }
            }
        }

        if state.isCompleted {
            // Completed ideas may eventually return unless the user enables Never Repeat,
            // but they should not crowd out discovery shortly after completion.
            value -= 8.0
            if let completedAt = state.completedAt {
                let hours = Date().timeIntervalSince(completedAt) / 3600
                if hours < 72 { value -= 24 }
                else if hours < 168 { value -= 15 }
                else if hours < 720 { value -= 7 }
                else if hours < 2160 { value -= 2 }
            }
        }

        return value
    }

    private func noveltyScore(for activity: DunnoActivity) -> Double {
        guard let state = interactions[activity.id] else { return 1.0 }
        if state.timesShown == 0 { return 1.0 }

        var novelty = max(0, 1.0 - Double(state.timesShown) * 0.16)
        if let lastShown = state.lastShown {
            let days = Date().timeIntervalSince(lastShown) / 86400
            novelty += min(0.45, max(0, days / 30) * 0.45)
        }
        return min(novelty, 1.0)
    }

    private func availableActivities(filters: DunnoFilters) -> [DunnoActivity] {
        activities.filter { activity in
            guard !isNotInterested(activity) else { return false }
            guard currentActivityID != activity.id else { return false }
            if neverRepeatCompleted && isCompleted(activity) { return false }
            return matches(activity, filters: filters)
        }
    }

    private func matches(_ activity: DunnoActivity, filters: DunnoFilters) -> Bool {
        // If someone says they have 10 minutes, the whole activity must fit inside that
        // window. A 10–90 minute idea is not a truthful 10-minute suggestion.
        if let max = filters.maxMinutes, activity.maxMinutes > max { return false }
        if let energy = filters.energy, activity.energy.level > energy.level { return false }

        if let context = filters.context,
           context != .anywhere,
           !activity.contexts.contains(context),
           !activity.contexts.contains(.anywhere) {
            return false
        }

        if let social = filters.social, social != .any {
            let universal = activity.social.contains(.any)
            if !activity.social.contains(social) && !universal {
                return false
            }
        }

        return true
    }

    /// Queue composition targets roughly 70% strong personal matches, 20% adjacent
    /// discoveries, and 10% true wildcards. Choosing “Surprise me” intentionally raises
    /// the wildcard share. Every lane still obeys Right Now filters and hard exclusions.
    private func buildRecommendationQueue(
        from candidates: [RecommendationCandidate],
        limit: Int?
    ) -> [DunnoActivity] {
        var strong = candidates.filter { $0.lane == .strong }.sorted { $0.score > $1.score }
        var adjacent = candidates.filter { $0.lane == .adjacent }.sorted { $0.score > $1.score }
        var wildcard = candidates.filter { $0.lane == .wildcard }.sorted(by: wildcardSort)

        // If onboarding signals happen to classify nearly everything into one lane, keep
        // the engine graceful rather than manufacturing weak recommendations.
        if strong.isEmpty {
            let fallback = (adjacent + wildcard).sorted { $0.score > $1.score }
            strong = Array(fallback.prefix(max(1, fallback.count / 2)))
            let strongIDs = Set(strong.map { $0.activity.id })
            adjacent.removeAll { strongIDs.contains($0.activity.id) }
            wildcard.removeAll { strongIDs.contains($0.activity.id) }
        }

        let outputLimit = min(max(limit ?? candidates.count, 0), candidates.count)
        guard outputLimit > 0 else { return [] }

        var output: [DunnoActivity] = []
        output.reserveCapacity(outputLimit)

        let wantsSurprise = profile.goals.contains {
            DunnoTaxonomy.normalize($0) == DunnoTaxonomy.normalize("Surprise me")
        }
        let pattern: [RecommendationLane] = wantsSurprise
            ? [.strong, .strong, .adjacent, .strong, .wildcard, .strong, .adjacent, .strong, .wildcard, .strong]
            : [.strong, .strong, .adjacent, .strong, .strong, .wildcard, .strong, .adjacent, .strong, .strong]

        var slot = 0
        while output.count < outputLimit && (!strong.isEmpty || !adjacent.isEmpty || !wildcard.isEmpty) {
            let requested = pattern[slot % pattern.count]
            let picked: RecommendationCandidate?

            switch requested {
            case .strong:
                picked = takeBestDiverse(from: &strong, previous: output)
                    ?? takeBestDiverse(from: &adjacent, previous: output)
                    ?? takeBestDiverse(from: &wildcard, previous: output)
            case .adjacent:
                picked = takeBestDiverse(from: &adjacent, previous: output)
                    ?? takeBestDiverse(from: &strong, previous: output)
                    ?? takeBestDiverse(from: &wildcard, previous: output)
            case .wildcard:
                picked = takeBestDiverse(from: &wildcard, previous: output, wildcard: true)
                    ?? takeBestDiverse(from: &adjacent, previous: output, wildcard: true)
                    ?? takeBestDiverse(from: &strong, previous: output, wildcard: true)
            }

            guard let picked else { break }
            output.append(picked.activity)
            slot += 1
        }

        return output
    }

    /// Looks at a bounded window of good candidates and picks the one that best improves
    /// variety. This is much cheaper than the old full O(n²) rerank while still preventing
    /// repetitive category/energy/duration streaks near the front of the queue.
    private func takeBestDiverse(
        from pool: inout [RecommendationCandidate],
        previous: [DunnoActivity],
        wildcard: Bool = false
    ) -> RecommendationCandidate? {
        guard !pool.isEmpty else { return nil }

        let lookahead = min(pool.count, 28)
        var bestIndex = 0
        var bestValue = -Double.infinity

        for index in 0..<lookahead {
            let candidate = pool[index]
            var adjusted = candidate.score

            if wildcard {
                // Exploration should be novel, not merely low-affinity.
                adjusted += candidate.novelty * 7.0
                adjusted -= max(0, candidate.affinity) * 0.18
            }

            adjusted += diversityAdjustment(for: candidate.activity, previous: previous)

            if adjusted > bestValue {
                bestValue = adjusted
                bestIndex = index
            }
        }

        return pool.remove(at: bestIndex)
    }

    private func diversityAdjustment(for activity: DunnoActivity, previous: [DunnoActivity]) -> Double {
        guard !previous.isEmpty else { return 0 }

        var value = 0.0
        let recent = Array(previous.suffix(5))

        if let last = recent.last {
            if last.category == activity.category { value -= 14 }
            if last.energy == activity.energy { value -= 1.0 }
            if DurationBand(last) == DurationBand(activity) { value -= 0.8 }
        }

        let categoryCount = recent.filter { $0.category == activity.category }.count
        if categoryCount > 0 {
            value -= Double(categoryCount) * 4.2
        } else {
            value += 1.4
        }

        let energyCount = recent.filter { $0.energy == activity.energy }.count
        if energyCount >= 3 { value -= 2.2 }

        let durationCount = recent.filter { DurationBand($0) == DurationBand(activity) }.count
        if durationCount >= 3 { value -= 1.8 }

        let signals = metadata(for: activity).signals
        for recentActivity in recent.suffix(2) {
            let overlap = signals.intersection(metadata(for: recentActivity).signals).count
            value -= min(2.4, Double(overlap) * 0.32)
        }

        return value
    }

    private func wildcardSort(_ lhs: RecommendationCandidate, _ rhs: RecommendationCandidate) -> Bool {
        let lhsValue = lhs.score + lhs.novelty * 8 + deterministicJitter(for: lhs.activity, amplitude: 3.2)
        let rhsValue = rhs.score + rhs.novelty * 8 + deterministicJitter(for: rhs.activity, amplitude: 3.2)
        return lhsValue > rhsValue
    }

    private func calibrationScore(for activity: DunnoActivity) -> Double {
        let metadata = metadata(for: activity)
        var value = calibrationAffinities[metadata.calibrationCategoryKey] ?? 0

        for key in metadata.calibrationTagKeys {
            value += calibrationAffinities[key] ?? 0
        }

        for key in metadata.calibrationGoalKeys {
            value += calibrationAffinities[key] ?? 0
        }

        return min(max(value, -8), 8)
    }

    private func behaviorScore(for activity: DunnoActivity) -> Double {
        let metadata = metadata(for: activity)
        var value = behaviorAffinities[metadata.calibrationCategoryKey] ?? 0

        for key in metadata.calibrationTagKeys {
            value += behaviorAffinities[key] ?? 0
        }
        for key in metadata.calibrationGoalKeys {
            value += behaviorAffinities[key] ?? 0
        }

        // Learned behavior should matter, but it should never overpower the moment.
        return min(max(value, -10), 10)
    }

    private func daypartScore(for activity: DunnoActivity, now: Date = Date()) -> Double {
        let metadata = metadata(for: activity)
        guard !metadata.preferredDayparts.isEmpty else { return 0 }

        let current = DunnoDaypart.current(date: now)
        if metadata.preferredDayparts.contains(current) {
            return metadata.strictDaypart ? 4.5 : 2.0
        }

        // Explicit sunset/night/morning ideas should become very unlikely at the wrong
        // time without creating a hard filter that can make a narrow Right Now set empty.
        return metadata.strictDaypart ? -30 : -5
    }

    private func feedbackScore(for activity: DunnoActivity) -> Double {
        let hidden = hiddenFeedbackSignals()
        guard !hidden.isEmpty else { return 0 }

        let candidateSignals = metadata(for: activity).signals
        var categoryPenalty = 0.0
        var similarityPenalty = 0.0

        for feedback in hidden {
            if feedback.category == activity.category {
                categoryPenalty += 0.9
            }

            let overlap = candidateSignals.intersection(feedback.signals).count
            similarityPenalty += min(1.15, Double(overlap) * 0.20)
        }

        // Multiple hidden ideas should teach Dunno, but they should not accidentally erase
        // a whole category forever. Exact hidden activities are already hard-excluded.
        return -(min(categoryPenalty, 3.8) + min(similarityPenalty, 4.2))
    }

    private func hiddenFeedbackSignals() -> [HiddenFeedbackSignal] {
        if let hiddenFeedbackCache { return hiddenFeedbackCache }

        let signals = activities.compactMap { activity -> HiddenFeedbackSignal? in
            guard isNotInterested(activity) else { return nil }
            return HiddenFeedbackSignal(
                category: activity.category,
                signals: metadata(for: activity).signals
            )
        }
        hiddenFeedbackCache = signals
        return signals
    }

    private func invalidateHiddenFeedbackCache() {
        hiddenFeedbackCache = nil
        hiddenActivitiesCache = nil
    }

    private func invalidateLibraryCaches() {
        savedActivitiesCache = nil
        completedActivitiesCache = nil
    }

    private func deterministicJitter(for activity: DunnoActivity, amplitude: Double) -> Double {
        let salt = metadata(for: activity).jitterSalt
        let mixed = UInt(bitPattern: salt &+ shuffleSeed &* 37)
        return Double(mixed % 10_000) / 10_000.0 * amplitude
    }

    private func metadata(for activity: DunnoActivity) -> ActivityMetadata {
        if let cached = activityMetadataCache[activity.id] {
            return cached
        }

        let timeMetadata = Self.daypartMetadata(for: activity)
        let metadata = ActivityMetadata(
            signals: DunnoTaxonomy.activitySignals(activity),
            normalizedGoals: Set(activity.goals.map(DunnoTaxonomy.normalize)),
            preferredDayparts: timeMetadata.dayparts,
            strictDaypart: timeMetadata.strict,
            nearbyKind: DunnoNearbyKind.infer(for: activity),
            calibrationCategoryKey: "category:\(DunnoTaxonomy.normalize(activity.category.rawValue))",
            calibrationTagKeys: activity.tags.map { "tag:\(DunnoTaxonomy.normalize($0))" },
            calibrationGoalKeys: activity.goals.map { "goal:\(DunnoTaxonomy.normalize($0))" },
            jitterSalt: activity.id.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) },
            searchableText: ([
                activity.title,
                activity.hook,
                activity.description,
                activity.category.rawValue
            ] + activity.tags + activity.goals)
                .joined(separator: " ")
                .lowercased()
        )
        activityMetadataCache[activity.id] = metadata
        return metadata
    }

    private func adjustAffinity(_ key: String, by amount: Double) {
        let next = (calibrationAffinities[key] ?? 0) + amount
        calibrationAffinities[key] = min(max(next, -4), 4)
    }

    private func applyBehaviorSignal(for activity: DunnoActivity, strength: Double) {
        let metadata = metadata(for: activity)
        var updated = behaviorAffinities

        func adjust(_ key: String, by amount: Double) {
            let next = (updated[key] ?? 0) + amount
            updated[key] = min(max(next, -5), 5)
        }

        adjust(metadata.calibrationCategoryKey, by: strength * 0.36)

        for key in metadata.calibrationTagKeys.prefix(5) {
            adjust(key, by: strength * 0.18)
        }
        for key in metadata.calibrationGoalKeys.prefix(3) {
            adjust(key, by: strength * 0.24)
        }

        // One assignment means one Published change instead of up to nine redraw-triggering
        // dictionary mutations for a single user action.
        behaviorAffinities = updated
        saveBehaviorAffinities()
    }

    private static func daypartMetadata(for activity: DunnoActivity) -> (dayparts: Set<DunnoDaypart>, strict: Bool) {
        let text = ([activity.title, activity.hook, activity.description] + activity.tags)
            .joined(separator: " ")
            .lowercased()
        let title = activity.title.lowercased()

        var dayparts: Set<DunnoDaypart> = []
        var strict = false

        if title.contains("tomorrow morning") {
            return ([.evening, .night], false)
        }

        let strictMorning = ["sunrise", "morning lap"]
        let strictEvening = ["sunset", "golden hour"]
        let strictNight = ["night walk", "night bike", "midnight", "late-night", "stargaz", "constellation", "stars or planets", "planet tonight", "identify one planet"]

        if strictMorning.contains(where: { title.contains($0) }) {
            dayparts.formUnion([.morning])
            strict = true
        }
        if strictEvening.contains(where: { title.contains($0) }) {
            dayparts.formUnion([.evening])
            strict = true
        }
        if strictNight.contains(where: { title.contains($0) }) {
            dayparts.formUnion([.night])
            strict = true
        }

        if !strict {
            if text.contains("morning") || text.contains("breakfast") { dayparts.insert(.morning) }
            if text.contains("lunch") { dayparts.insert(.daytime) }
            if text.contains("evening") || text.contains("dinner") { dayparts.insert(.evening) }
            if text.contains("night") || text.contains("moon") || text.contains("stars") { dayparts.insert(.night) }
        }

        return (dayparts, strict)
    }

    // MARK: - Persistence + migration

    private enum InteractionDateKind {
        case saved
        case completed
    }

    private func interactionDate(for activity: DunnoActivity, kind: InteractionDateKind) -> Date {
        guard let state = interactions[activity.id] else { return .distantPast }
        switch kind {
        case .saved:
            return state.savedAt ?? state.lastShown ?? .distantPast
        case .completed:
            return state.completedAt ?? state.lastShown ?? .distantPast
        }
    }

    private func sanitizePersistedState() {
        let validIDs = Set(activities.map(\.id))
        let originalCount = interactions.count
        interactions = interactions.filter { validIDs.contains($0.key) }
        invalidateHiddenFeedbackCache()
        invalidateLibraryCaches()

        if originalCount != interactions.count {
            saveInteractions()
        }

        if let currentActivityID, !validIDs.contains(currentActivityID) {
            clearCurrentActivity()
        }

        if let completionFeedbackActivityID, !validIDs.contains(completionFeedbackActivityID) {
            dismissCompletionFeedback()
        }

        let originalCollections = collections
        collections = collections.map { collection in
            var copy = collection
            copy.activityIDs = copy.activityIDs.filter { validIDs.contains($0) }
            return copy
        }
        if collections != originalCollections { saveCollections() }
    }


    /// Exposure and lightweight feedback can happen on animation/tap frames. Persist them
    /// shortly afterward so JSON encoding does not compete with gesture or card animation
    /// work. Critical library/current-activity actions still persist immediately.
    private func scheduleInteractionSave() {
        exposureSaveTask?.cancel()
        exposureSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            self?.saveInteractions()
        }
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: profileKey)
        }
    }

    private func saveInteractions() {
        persistenceWriter.save(interactions, key: interactionKey)
    }

    private func saveCalibration() {
        if let data = try? JSONEncoder().encode(calibrationAffinities) {
            defaults.set(data, forKey: calibrationKey)
        }
    }

    private func saveBehaviorAffinities() {
        persistenceWriter.save(behaviorAffinities, key: behaviorAffinityKey)
    }

    private func saveCollections() {
        if let data = try? JSONEncoder().encode(collections) {
            defaults.set(data, forKey: collectionsKey)
        }
    }

    private func removeFromAllCollections(_ activity: DunnoActivity) {
        var changed = false
        for index in collections.indices where collections[index].activityIDs.contains(activity.id) {
            collections[index].activityIDs.removeAll { $0 == activity.id }
            changed = true
        }
        if changed { saveCollections() }
    }

    /// Used by App Intents that create a temporary store and need their background
    /// persistence to land before the intent hands control back to the running app.
    func flushPersistence() {
        persistenceWriter.flush()
    }

    private static func sanitizedSelections(_ values: [String], allowed: [String]) -> [String] {
        let allowedSet = Set(allowed)
        var seen: Set<String> = []
        return values.filter { value in
            guard allowedSet.contains(value), !seen.contains(value) else { return false }
            seen.insert(value)
            return true
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

nonisolated private final class DunnoDefaultsBox: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) {
        self.value = value
    }
}

/// JSON encoding the entire interaction dictionary was happening on the main actor during
/// Done, note saves, feedback, and other taps. A serial utility queue preserves write order
/// while keeping that work off the interaction frame.
nonisolated private final class DunnoPersistenceWriter: @unchecked Sendable {
    private let defaultsBox: DunnoDefaultsBox
    private let queue = DispatchQueue(label: "com.codearc.dunno.persistence", qos: .utility)

    init(defaults: UserDefaults) {
        defaultsBox = DunnoDefaultsBox(defaults)
    }

    func save<T: Encodable & Sendable>(_ value: T, key: String) {
        let defaultsBox = defaultsBox
        queue.async {
            guard let data = try? JSONEncoder().encode(value) else { return }
            defaultsBox.value.set(data, forKey: key)
        }
    }

    func flush() {
        queue.sync { }
    }
}

private extension Array where Element == String {
    mutating func toggle(_ value: String) {
        if let index = firstIndex(of: value) {
            remove(at: index)
        } else {
            append(value)
        }
    }
}
