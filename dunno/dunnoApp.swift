import SwiftUI

@main
struct dunnoApp: App {
    @StateObject private var store = DunnoStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(DunnoAppearance.storageKey) private var appearanceRawValue = DunnoAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(
                    (DunnoAppearance(rawValue: appearanceRawValue) ?? .system).colorScheme
                )
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.expireCurrentActivityIfNeeded()
                        store.expireFiltersIfNeeded()
                    }
                }
        }
    }
}
