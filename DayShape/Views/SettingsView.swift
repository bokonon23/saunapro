import SwiftUI
import SwiftData
import HealthKit

struct SettingsView: View {
    @AppStorage("detectionSensitivity") private var detectionSensitivity: Double = 1.5
    @AppStorage("saunaMinMinutes") private var saunaMinMinutes: Double = 10
    @AppStorage("habitualStartHour") private var habitualStartHour: Int = 0
    @AppStorage("habitualEndHour") private var habitualEndHour: Int = 0
    @AppStorage("hasScannedHistory") private var hasScannedHistory = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @State private var showRescanConfirmation = false
    @State private var didRescan = false
    @State private var selectedTriggers: Set<UInt> = WorkoutTrigger.savedTriggers()
    @State private var showWelcomeScreen = false

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
                    ForEach(WorkoutTrigger.allCases) { trigger in
                        Button {
                            if selectedTriggers.contains(trigger.id) {
                                // Don't allow deselecting all triggers
                                if selectedTriggers.count > 1 {
                                    selectedTriggers.remove(trigger.id)
                                }
                            } else {
                                selectedTriggers.insert(trigger.id)
                            }
                            WorkoutTrigger.saveTriggers(selectedTriggers)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: trigger.icon)
                                    .font(.title3)
                                    .foregroundStyle(selectedTriggers.contains(trigger.id) ? .orange : .secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trigger.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(trigger.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: selectedTriggers.contains(trigger.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedTriggers.contains(trigger.id) ? .orange : .secondary)
                            }
                        }
                    }
                } header: {
                    Text("Workout Triggers")
                } footer: {
                    Text("Select which workout types your watch uses for sauna sessions. Apple Watch users: use \"Other\". Garmin users: try \"Yoga\" or \"Mind & Body\".")
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

                Section("Apple Watch") {
                    HStack {
                        Label("Watch App", systemImage: "applewatch")
                        Spacer()
                        if PhoneConnectivityManager.shared.isPaired {
                            Text("Paired")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("Not Paired")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if PhoneConnectivityManager.shared.isPaired {
                        HStack {
                            Text("Connection")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(PhoneConnectivityManager.shared.isReachable ? "Active" : "Standby")
                                .font(.caption)
                                .foregroundStyle(PhoneConnectivityManager.shared.isReachable ? .green : .yellow)
                        }
                    }
                }

                Section("About") {
                    Label("SaunaPro v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")", systemImage: "info.circle")
                    Label("Sauna & Cold Exposure Tracking", systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    Button {
                        showWelcomeScreen = true
                    } label: {
                        Label("Show Welcome Screen", systemImage: "hand.wave")
                    }
                }
            }
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showWelcomeScreen) {
                WelcomeView(hasCompletedOnboarding: .constant(false))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            showWelcomeScreen = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding()
                        }
                    }
            }
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
