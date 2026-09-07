import Foundation

#if DEBUG
/// Lightweight, deterministic release invariants that run once in DEBUG builds.
/// These are intentionally isolated from the user's real defaults and catch regressions
/// in the behaviors that are easiest to break while Dunno is still moving quickly.
@MainActor
enum DunnoReleaseChecks {
    private static var hasRun = false

    static func runOnce() {
        guard !hasRun else { return }
        hasRun = true

        let suiteName = "studio.codearc.dunno.release-checks"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            assertionFailure("Dunno release checks could not create isolated UserDefaults.")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DunnoStore(defaults: defaults, runDiagnostics: false)
        var failures: [String] = []

        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        check(store.activities.count >= 250, "Release catalog should contain at least 250 activities.")
        check(Set(store.activities.map(\.id)).count == store.activities.count, "Activity IDs must remain unique.")

        // Right Now is a promise. Results must never violate the user's time limit.
        for limit in [10, 20, 30, 60] {
            let results = store.recommendations(
                filters: DunnoFilters(maxMinutes: limit, energy: nil, context: nil, social: nil)
            )
            check(!results.isEmpty, "A \(limit)-minute filter should have at least one result.")
            check(
                results.allSatisfy { $0.maxMinutes <= limit },
                "A \(limit)-minute filter returned an activity that does not fully fit."
            )
        }

        // Every combination exposed by Right Now should have at least one valid idea.
        // This protects the meaning of `Anyone`: it is a universal social tag even when
        // an activity also includes more specific social tags.
        let timeOptions: [Int?] = [nil, 10, 15, 30, 60, 120]
        let energyOptions: [DunnoEnergy?] = [nil] + DunnoEnergy.allCases.map(Optional.some)
        let contextOptions: [DunnoContext?] = [nil] + DunnoContext.allCases
            .filter { $0 != .anywhere }
            .map(Optional.some)
        let socialOptions: [DunnoSocial?] = [nil] + DunnoSocial.allCases
            .filter { $0 != .any }
            .map(Optional.some)

        for maxMinutes in timeOptions {
            for energy in energyOptions {
                for context in contextOptions {
                    for social in socialOptions {
                        let filters = DunnoFilters(
                            maxMinutes: maxMinutes,
                            energy: energy,
                            context: context,
                            social: social
                        )
                        check(
                            store.matchingCount(filters: filters) > 0,
                            "A visible Right Now filter combination returned zero matching ideas."
                        )
                    }
                }
            }
        }

        if let universalCandidate = store.activities.first(where: {
            $0.social.contains(.any) && !$0.social.contains(.family)
        }) {
            let familyResults = store.recommendations(
                filters: DunnoFilters(maxMinutes: nil, energy: nil, context: nil, social: .family)
            )
            check(
                familyResults.contains(where: { $0.id == universalCandidate.id }),
                "An activity tagged Anyone must match a concrete social filter even when other social tags are present."
            )
        } else {
            failures.append("Release catalog needs an Anyone-tagged activity that proves universal social matching.")
        }

        if let first = store.activities.first {
            store.showLessLikeThis(first)
            check(
                !store.recommendations().contains(where: { $0.id == first.id }),
                "Show me less like this must suppress the exact activity from For You."
            )

            store.restoreSuggestion(first, refresh: false)
            check(!store.isNotInterested(first), "Restoring a hidden suggestion should clear its hidden state.")

            store.beginCurrentActivity(first)
            check(store.currentActivityID == first.id, "Starting an activity should establish Doing Now state.")
            check(
                !store.recommendations().contains(where: { $0.id == first.id }),
                "The current Doing Now activity must not be recommended again."
            )
            store.cancelCurrentActivity()
            check(store.currentActivityID == nil, "Cancelling Doing Now should clear the current activity.")

            store.toggleSaved(first)
            check(store.isSaved(first), "Save for later should persist saved state.")
            check(!store.behaviorAffinities.isEmpty, "Saving an idea should create a small behavior-learning signal.")
            store.beginCurrentActivity(first)
            store.complete(first)
            check(store.isCompleted(first), "Completing an activity should add it to Did It.")
            check(!store.isSaved(first), "Completed activities should leave Saved and live in Did It.")

            let additional = Array(store.activities.dropFirst().prefix(2))
            for activity in additional {
                store.beginCurrentActivity(activity)
                store.complete(activity)
            }
            check(
                store.completionFeedbackActivity != nil,
                "Dunno should occasionally ask for low-friction completion feedback after real use."
            )
            if let feedbackActivity = store.completionFeedbackActivity {
                store.submitCompletionFeedback(for: feedbackActivity, positive: true)
                check(
                    store.interactions[feedbackActivity.id]?.completionFeedback == 1,
                    "Positive completion feedback should persist as on-device learning data."
                )
            }
            check(
                store.reviewRequestPending,
                "Completing three activities should make a native review request eligible."
            )
            store.markReviewRequestAttempted()
            check(
                !store.reviewRequestPending,
                "Recording a review request attempt should clear review eligibility."
            )

            store.setNeverRepeatCompleted(true)
            check(
                !store.recommendations().contains(where: { $0.id == first.id }),
                "Never repeat completed ideas must exclude completed activities from For You."
            )

            store.removeCompleted(first)
            check(!store.isCompleted(first), "Removing an activity from Did It should clear completion state.")

            store.resetBehaviorLearning()
            check(store.behaviorAffinities.isEmpty, "Reset learned taste should clear behavior affinities.")
            check(
                store.interactions.values.allSatisfy { $0.timesStarted == 0 && $0.timesCompleted == 0 && $0.saveLearningSignals == 0 && $0.completionFeedback == nil },
                "Reset learned taste should clear behavior-learning counters without clearing library state."
            )
        }

        // The first page should have meaningful category variety even without profile data.
        let firstPage = Array(store.recommendations().prefix(12))
        let categoryCounts = Dictionary(grouping: firstPage, by: \.category).mapValues { $0.count }
        let largestCategoryRun = categoryCounts.values.max() ?? 0
        check(largestCategoryRun <= 4, "The first 12 recommendations are too concentrated in one category.")

        if failures.isEmpty {
            print("✅ Dunno release checks passed")
        } else {
            assertionFailure(
                "Dunno release checks failed:\n" + failures.map { "• \($0)" }.joined(separator: "\n")
            )
        }
    }
}
#endif
