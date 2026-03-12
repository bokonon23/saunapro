//
//  ContentView.swift
//  SaunaPro
//
//  Created by Bruce Milligan on 11/03/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "flame") {
                TodayView()
            }
            Tab("History", systemImage: "calendar") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
