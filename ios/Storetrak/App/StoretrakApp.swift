import SwiftUI

@main
struct StoretrakApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isLoggedIn {
                MainTabView()
                    .environmentObject(appState)
                    .task { await appState.loadAll() }
            } else {
                LoginView()
                    .environmentObject(appState)
            }
        }
    }
}
