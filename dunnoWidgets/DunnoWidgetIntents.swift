import AppIntents
import WidgetKit

nonisolated struct NextDunnoWidgetIdeaIntent: AppIntent {
    static let title: LocalizedStringResource = "Different idea"
    static let description = IntentDescription("Shows another Dunno idea in the widget.")

    func perform() async throws -> some IntentResult {
        DunnoSharedSystemState.advanceSuggestion()
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: DunnoSharedSystemState.widgetKind)
        }
        return .result()
    }
}

struct StartDunnoWidgetIdeaIntent: AppIntent {
    static let title: LocalizedStringResource = "Do this"
    static let description = IntentDescription("Starts the idea shown in your Dunno widget.")

    @Parameter(title: "Activity ID")
    var activityID: String

    init() {
        activityID = ""
    }

    init(activityID: String) {
        self.activityID = activityID
    }

    func perform() async throws -> some IntentResult {
        guard let activity = DunnoSharedSystemState.suggestions().first(where: { $0.id == activityID }) else {
            return .result()
        }

        DunnoSharedSystemState.setCurrentActivity(activity)
        await MainActor.run {
            WidgetCenter.shared.reloadTimelines(ofKind: DunnoSharedSystemState.widgetKind)

            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadAllControls()
            }
        }

        return .result()
    }
}
