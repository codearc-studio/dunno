import AppIntents
import Foundation

nonisolated struct GiveMeSomethingToDoIntent: AppIntent {
    static let title: LocalizedStringResource = "Give me something to do"
    static let description = IntentDescription("Picks a Dunno idea and opens it as your current activity.")
    static var openAppWhenRun: Bool { true }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let activityTitle: String? = await MainActor.run {
            let intentStore = DunnoStore(runDiagnostics: false)
            guard let activity = intentStore.recommendations(limit: 1).first else { return nil }
            intentStore.beginCurrentActivity(activity)
            intentStore.flushPersistence()
            NotificationCenter.default.post(name: .dunnoIntentStateDidChange, object: nil)
            return activity.title
        }

        guard let activityTitle else {
            return .result(dialog: "I couldn't find a good fit. Open Dunno to adjust your choices.")
        }

        return .result(dialog: "Try \(activityTitle). I opened it in Dunno for you.")
    }
}

nonisolated struct DunnoAppShortcuts: AppShortcutsProvider {
    nonisolated static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GiveMeSomethingToDoIntent(),
            phrases: [
                "Give me something to do with \(.applicationName)",
                "I'm bored with \(.applicationName)",
                "What should I do with \(.applicationName)"
            ],
            shortTitle: "Something to do",
            systemImageName: "sparkles"
        )
    }
}

extension Notification.Name {
    static let dunnoIntentStateDidChange = Notification.Name("dunno.intent.stateDidChange")
}
