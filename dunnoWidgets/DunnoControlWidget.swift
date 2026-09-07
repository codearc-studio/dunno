import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct DunnoControlWidget: ControlWidget {
    static let kind = "com.codearc.dunno.control.open"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenDunnoIntent(target: .forYou)) {
                Label("dunno?", systemImage: "sparkles")
            }
        }
        .displayName("dunno?")
        .description("Open Dunno and find something to do.")
    }
}
