import SwiftUI

@main
struct dunnoApp: App {
    @StateObject private var store = DunnoStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.expireCurrentActivityIfNeeded()
                        store.expireFiltersIfNeeded()
                    }
                }
        }
    }
}
