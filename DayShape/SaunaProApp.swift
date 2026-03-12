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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: SessionRecord.self)
    }
}
