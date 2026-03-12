import SwiftUI

struct SettingsView: View {
    @State private var detectionSensitivity: Double = 1.6

    var body: some View {
        NavigationStack {
            List {
                Section("Data Source") {
                    HStack {
                        Label("HealthKit", systemImage: "heart.circle")
                        Spacer()
                        if HealthKitManager.shared.isAvailable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Simulator")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Section("Detection") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Sensitivity")
                        Slider(value: $detectionSensitivity, in: 1.3...2.0, step: 0.1) {
                            Text("Sensitivity")
                        }
                        Text("Elevation threshold: \(String(format: "%.1f", detectionSensitivity))x baseline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    Label("SaunaPro v1.0", systemImage: "info.circle")
                    Label("AI-Powered Sauna & Cold Plunge Coach", systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
