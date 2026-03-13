import SwiftUI

@main
struct SaunaProWatchApp: App {
    @State private var workoutManager = WatchWorkoutManager()

    init() {
        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            SessionView()
                .environment(workoutManager)
        }
    }
}
