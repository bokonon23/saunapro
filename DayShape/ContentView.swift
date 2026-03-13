//
//  ContentView.swift
//  SaunaPro
//
//  Created by Bruce Milligan on 11/03/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView {
                    Tab("Day View", systemImage: "flame") {
                        DayView()
                    }
                    Tab("History", systemImage: "calendar") {
                        HistoryView()
                    }
                    Tab("Settings", systemImage: "gearshape") {
                        SettingsView()
                    }
                }
                .tint(.orange)
            } else {
                WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
