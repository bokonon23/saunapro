import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Data Source") {
                    Label("HealthKit", systemImage: "heart.circle")
                    Label("Import CSV", systemImage: "doc.badge.arrow.up")
                }

                Section("Detection") {
                    Label("Event Sensitivity", systemImage: "slider.horizontal.3")
                }

                Section("About") {
                    Label("Version 1.0", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
