import SwiftUI
import TipKit

struct DunnoNotNowTip: Tip {
    var title: Text { Text("Not Now stays temporary") }
    var message: Text? { Text("Swipe left when it just isn't right now. Use Show me less like this only when you actually want Dunno to learn from it.") }
    var image: Image? { Image(systemName: "arrow.left") }
}

struct DunnoSystemSurfacesTip: Tip {
    var title: Text { Text("Dunno works outside the app") }
    var message: Text? { Text("Add a widget, Lock Screen shortcut, or Control Center control to get an idea faster.") }
    var image: Image? { Image(systemName: "rectangle.3.group") }
}

struct DunnoMinimizeTip: Tip {
    var title: Text { Text("You don't have to finish yet") }
    var message: Text? { Text("Minimize keeps this activity running in the tab bar and Live Activity without marking it done.") }
    var image: Image? { Image(systemName: "arrow.down.right.and.arrow.up.left") }
}

enum DunnoTipConfiguration {
    static func configure() {
        do {
            try Tips.configure([
                .displayFrequency(.daily)
            ])
        } catch {
            #if DEBUG
            print("Dunno TipKit configuration failed: \(error)")
            #endif
        }
    }
}
