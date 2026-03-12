import SwiftUI
import SwiftData
import Charts

struct DayView: View {
    @State private var dataManager = DataManager()
    @State private var selectedDate = Date()
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasScannedHistory") private var hasScannedHistory = false

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var dateTitle: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E d MMM"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date navigation bar
                    dateNavigationBar

                    if dataManager.isLoading {
                        ProgressView("Loading health data...")
                            .padding(.top, 60)
                    } else if let dayData = dataManager.dayData {
                        if dataManager.isUsingSimulatorData {
                            Label("Sample data (Apple Watch Ultra sim)", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .padding(.horizontal)
                        }

                        if let progress = dataManager.historyScanProgress {
                            Label(progress, systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.horizontal)
                        }

                        HeartRateChartView(samples: dayData.heartRateSamples, sessions: dataManager.sessions)
                            .padding(.horizontal)

                        if dataManager.sessions.isEmpty {
                            ContentUnavailableView(
                                "No Sessions Detected",
                                systemImage: "flame",
                                description: Text("No sauna or cold plunge sessions found \(isToday ? "today" : "this day").")
                            )
                            .padding(.top, 20)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(dataManager.sessions.count) Session\(dataManager.sessions.count == 1 ? "" : "s")")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(dataManager.sessions) { session in
                                    NavigationLink(value: session) {
                                        SessionCardView(session: session)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 24) {
                            Spacer().frame(height: 60)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse)
                            Text("SaunaPro")
                                .font(.largeTitle.bold())
                            Text("Track your sauna & cold plunge sessions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Day View")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SessionRecord.self) { session in
                SessionDetailView(session: session, dayData: dataManager.dayData)
            }
            .refreshable {
                await loadSelectedDay()
            }
            .task {
                await loadSelectedDay()

                // On first launch, scan the last 30 days
                if !hasScannedHistory {
                    await dataManager.scanHistory(days: 30, modelContext: modelContext)
                    hasScannedHistory = true
                }
            }
            .onChange(of: selectedDate) {
                Task {
                    await loadSelectedDay()
                }
            }
        }
    }

    // MARK: - Date Navigation

    private var dateNavigationBar: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(dateTitle)
                    .font(.title3.bold())

                if !isToday {
                    let formatter = DateFormatter()
                    Text({
                        let f = DateFormatter()
                        f.dateFormat = "d MMMM yyyy"
                        return f.string(from: selectedDate)
                    }())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
                    .foregroundStyle(isToday ? .gray.opacity(0.3) : .orange)
            }
            .disabled(isToday)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    // MARK: - Loading

    private func loadSelectedDay() async {
        await dataManager.loadDay(selectedDate)
        saveDaySessions()
    }

    private func saveDaySessions() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayKey = dateFormatter.string(from: selectedDate)

        // Remove old auto-detected sessions for this day and replace with fresh detection
        let descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.dateKey == dayKey && $0.source == "autoDetected" }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for old in existing {
                modelContext.delete(old)
            }
        }

        for session in dataManager.sessions {
            modelContext.insert(session)
        }
        try? modelContext.save()
    }
}

#Preview {
    DayView()
        .preferredColorScheme(.dark)
        .modelContainer(for: SessionRecord.self, inMemory: true)
}
