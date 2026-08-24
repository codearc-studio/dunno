import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if store.profile.onboardingComplete {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DunnoMotion.settle, value: store.profile.onboardingComplete)
    }
}

#Preview {
    ContentView()
        .environmentObject(DunnoStore(defaults: UserDefaults(suiteName: "preview.dunno")!, runDiagnostics: false))
}
