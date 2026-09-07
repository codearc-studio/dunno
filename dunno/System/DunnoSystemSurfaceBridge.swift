import ActivityKit
import Foundation
import WidgetKit

@MainActor
enum DunnoSystemSurfaceBridge {
    private static var surfaceRefreshTask: Task<Void, Never>?
    private static var didRepairLiveActivityThisLaunch = false

    static func publishSuggestions(_ activities: [DunnoActivity]) {
        let suggestions = activities.prefix(12).map(sharedSuggestion)
        DunnoSharedSystemState.replaceSuggestions(Array(suggestions))
        scheduleSystemSurfaceRefresh()
    }

    static func mirrorCurrentActivity(_ activity: DunnoActivity, startedAt: Date, timerEndAt: Date? = nil) {
        didRepairLiveActivityThisLaunch = true
        DunnoSharedSystemState.setCurrentActivity(
            sharedSuggestion(activity),
            startedAt: startedAt,
            timerEndAt: timerEndAt
        )
        scheduleSystemSurfaceRefresh()
        restartLiveActivity(activity, startedAt: startedAt, timerEndAt: timerEndAt)
    }

    static func updateCurrentActivity(_ activity: DunnoActivity, startedAt: Date, timerEndAt: Date?) {
        DunnoSharedSystemState.setCurrentActivity(
            sharedSuggestion(activity),
            startedAt: startedAt,
            timerEndAt: timerEndAt
        )
        scheduleSystemSurfaceRefresh()

        let content = ActivityContent(
            state: liveState(for: activity, timerEndAt: timerEndAt),
            staleDate: timerEndAt
        )

        Task {
            let matching = Activity<DunnoActivityAttributes>.activities.filter {
                $0.attributes.id == activity.id
            }

            if matching.isEmpty {
                await MainActor.run {
                    restartLiveActivity(activity, startedAt: startedAt, timerEndAt: timerEndAt)
                }
                return
            }

            for liveActivity in matching {
                await liveActivity.update(content)
            }
        }
    }

    static func clearCurrentActivity() {
        DunnoSharedSystemState.clearCurrentActivity()
        scheduleSystemSurfaceRefresh()
        endLiveActivities()
    }

    /// Rebuild once per app process so a Live Activity created by an older development
    /// schema cannot stay on the Lock Screen with partially decoded/blank content.
    static func repairCurrentActivityIfNeeded(
        _ activity: DunnoActivity,
        startedAt: Date,
        timerEndAt: Date?
    ) {
        guard !didRepairLiveActivityThisLaunch else { return }
        didRepairLiveActivityThisLaunch = true

        DunnoSharedSystemState.setCurrentActivity(
            sharedSuggestion(activity),
            startedAt: startedAt,
            timerEndAt: timerEndAt
        )
        scheduleSystemSurfaceRefresh()
        restartLiveActivity(activity, startedAt: startedAt, timerEndAt: timerEndAt)
    }

    static func sharedCurrentActivity() -> DunnoSharedCurrentActivity? {
        DunnoSharedSystemState.currentActivity()
    }

    private static func sharedSuggestion(_ activity: DunnoActivity) -> DunnoSharedSuggestion {
        DunnoSharedSuggestion(
            id: activity.id,
            title: activity.title,
            hook: activity.hook,
            category: activity.category.rawValue,
            symbol: activity.symbol,
            duration: activity.durationLabel
        )
    }

    private static func liveState(
        for activity: DunnoActivity,
        timerEndAt: Date?
    ) -> DunnoActivityAttributes.ContentState {
        DunnoActivityAttributes.ContentState(
            title: activity.title,
            category: activity.category.rawValue,
            symbol: activity.symbol,
            duration: activity.durationLabel,
            timerEndAt: timerEndAt
        )
    }

    /// Widget/Control Center reloads do real extension work. Coalesce them and move them
    /// off the user's tap frame; the shared state itself is already written synchronously.
    private static func scheduleSystemSurfaceRefresh() {
        surfaceRefreshTask?.cancel()
        surfaceRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }

            WidgetCenter.shared.reloadTimelines(ofKind: DunnoSharedSystemState.widgetKind)
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadAllControls()
            }
            surfaceRefreshTask = nil
        }
    }

    private static func restartLiveActivity(
        _ activity: DunnoActivity,
        startedAt: Date,
        timerEndAt: Date?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DunnoActivityAttributes(
            id: activity.id,
            title: activity.title,
            category: activity.category.rawValue,
            symbol: activity.symbol,
            duration: activity.durationLabel,
            startedAt: startedAt
        )
        let content = ActivityContent(
            state: liveState(for: activity, timerEndAt: timerEndAt),
            staleDate: timerEndAt
        )

        Task {
            for existing in Activity<DunnoActivityAttributes>.activities {
                await existing.end(nil, dismissalPolicy: .immediate)
            }

            do {
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } catch {
                #if DEBUG
                print("Dunno Live Activity could not start: \(error)")
                #endif
            }
        }
    }

    private static func endLiveActivities() {
        Task {
            for activity in Activity<DunnoActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
