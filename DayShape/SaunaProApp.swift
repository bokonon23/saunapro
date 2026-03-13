//
//  SaunaProApp.swift
//  SaunaPro
//
//  Created by Bruce Milligan on 11/03/2026.
//

import SwiftUI
import SwiftData

@main
struct SaunaProApp: App {
    @State private var dataManager = DataManager()

    init() {
        PhoneConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environment(dataManager)
                .onReceive(NotificationCenter.default.publisher(for: .watchSessionReceived)) { notification in
                    guard let watchData = notification.object as? WatchSessionData else { return }
                    dataManager.importWatchSession(watchData)
                }
        }
        .modelContainer(for: SessionRecord.self)
    }
}
