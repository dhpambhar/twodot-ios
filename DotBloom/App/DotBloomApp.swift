import SwiftUI

@main
struct DotBloomApp: App {
    @StateObject private var store = ProgressStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
    }
}
