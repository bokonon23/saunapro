import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("detectionSensitivity") private var detectionSensitivity: Double = 1.5
    @AppStorage("saunaMinMinutes") private var saunaMinMinutes: Double = 10
    @AppStorage("habitualStartHour") private var habitualStartHour: Int = 0
    @AppStorage("habitualEndHour") private var habitualEndHour: Int = 0
    @AppStorage("hasScannedHistory") private var hasScannedHistory = false
    @Environment(\.modelContext) private var modelContext
    @State private var showRescanConfirmation = false
    @State private var didRescan = false

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

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HR Elevation Threshold")
                        Slider(value: $detectionSensitivity, in: 1.3...2.0, step: 0.1) {
                            Text("Sensitivity")
                        }
                        Text("HR must reach \(String(format: "%.1f", detectionSensitivity))x your baseline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Sauna Duration")
                        Slider(value: $saunaMinMinutes, in: 5...20, step: 1) {
                            Text("Duration")
                        }
                        Text("\(Int(saunaMinMinutes)) minutes minimum")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Detection")
                } footer: {
                    Text("Higher thresholds reduce false positives. Step count and workout data are also used to filter out exercise.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Usual Sauna Time")
                            .font(.subheadline)

                        HStack {
                            Picker("From", selection: $habitualStartHour) {
                                Text("Not set").tag(0)
                                ForEach(5..<23) { hour in
                                    Text(hourString(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)

                            Text("to")

                            Picker("To", selection: $habitualEndHour) {
                                Text("Not set").tag(0)
                                ForEach(6..<24) { hour in
                                    Text(hourString(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                } header: {
                    Text("Habitual Pattern")
                } footer: {
                    Text("Sessions detected during your usual sauna time get a confidence boost, reducing false negatives.")
                }

                Section {
                    Button(didRescan ? "Done! Go to Day View to scan." : "Rescan Last 30 Days") {
                        showRescanConfirmation = true
                    }
                    .foregroundStyle(didRescan ? .green : .orange)
                    .confirmationDialog("Rescan History", isPresented: $showRescanConfirmation) {
                        Button("Clear & Rescan", role: .destructive) {
                            // Delete all auto-detected sessions
                            let descriptor = FetchDescriptor<SessionRecord>(
                                predicate: #Predicate<SessionRecord> { $0.source == "autoDetected" }
                            )
                            if let existing = try? modelContext.fetch(descriptor) {
                                for session in existing {
                                    modelContext.delete(session)
                                }
                                try? modelContext.save()
                            }
                            hasScannedHistory = false
                            didRescan = true
                        }
                    } message: {
                        Text("This will delete all auto-detected sessions and rescan with your current settings.")
                    }
                } footer: {
                    Text("Clears saved sessions and rescans your HealthKit data with current detection settings. Switch to Day View after to trigger the scan.")
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

    private func hourString(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
