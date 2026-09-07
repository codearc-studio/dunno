import SwiftUI
import WidgetKit

@main
struct DunnoWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        DunnoSuggestionWidget()
        DunnoLiveActivity()

        if #available(iOS 18.0, *) {
            DunnoControlWidget()
        }
    }
}
