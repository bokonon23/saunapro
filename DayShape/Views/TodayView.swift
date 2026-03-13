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
                                        SessionCardView(
                                            session: session,
                                            onConfirm: { confirmSession(session) },
                                            onDismiss: { dismissSession(session) },
                                            onChangeType: { changeSessionType(session) }
                                        )
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

        // Merge in confirmed/dismissed sessions from SwiftData that fresh detection might miss
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayKey = dateFormatter.string(from: selectedDate)
        let detectedStatus = SessionStatus.detected.rawValue
        let confirmedDescriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate {
                $0.dateKey == dayKey && $0.status != detectedStatus
            }
        )
        if let confirmedSessions = try? modelContext.fetch(confirmedDescriptor) {
            // Remove any freshly-detected sessions that overlap with confirmed ones
            dataManager.sessions.removeAll { fresh in
                confirmedSessions.contains { confirmed in
                    fresh.startTime < confirmed.endTime && fresh.endTime > confirmed.startTime
                }
            }
            // Add the confirmed sessions back in
            dataManager.sessions.append(contentsOf: confirmedSessions)
            // Sort by start time
            dataManager.sessions.sort { $0.startTime < $1.startTime }
        }

        saveDaySessions()
    }

    private func confirmSession(_ session: SessionRecord) {
        // Ensure the session is in SwiftData before updating
        ensureInserted(session)
        session.status = SessionStatus.confirmed.rawValue
        try? modelContext.save()
    }

    private func dismissSession(_ session: SessionRecord) {
        ensureInserted(session)
        session.status = SessionStatus.dismissed.rawValue
        try? modelContext.save()
        // Remove from the current view
        dataManager.sessions.removeAll { $0.id == session.id }
    }

    private func changeSessionType(_ session: SessionRecord) {
        ensureInserted(session)
        // Toggle between sauna and cold exposure
        if session.type == .sauna {
            session.sessionType = SessionType.coldPlunge.rawValue
        } else {
            session.sessionType = SessionType.sauna.rawValue
        }
        try? modelContext.save()
    }

    /// Make sure a session is tracked by SwiftData before mutating it.
    /// Freshly-detected sessions from loadDay() are plain objects not yet inserted.
    private func ensureInserted(_ session: SessionRecord) {
        if session.modelContext == nil {
            modelContext.insert(session)
        }
    }

    private func saveDaySessions() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayKey = dateFormatter.string(from: selectedDate)

        // Only delete sessions that are still in "detected" status — preserve confirmed/dismissed
        // Also delete stale exercise sessions (they're re-created fresh from HealthKit each load)
        let detectedStatus = SessionStatus.detected.rawValue
        let autoSource = SessionSource.autoDetected.rawValue
        let exerciseType = SessionType.exercise.rawValue
        let descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate {
                $0.dateKey == dayKey && (
                    ($0.source == autoSource && $0.status == detectedStatus) ||
                    $0.sessionType == exerciseType
                )
            }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for old in existing {
                modelContext.delete(old)
            }
        }

        // Fetch all preserved (confirmed/dismissed) sessions for this day (excluding exercise)
        let confirmedDescriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate {
                $0.dateKey == dayKey && $0.status != detectedStatus && $0.sessionType != exerciseType
            }
        )
        let preservedSessions = (try? modelContext.fetch(confirmedDescriptor)) ?? []
        let preservedIDs = Set(preservedSessions.map(\.id))

        for session in dataManager.sessions {
            // Skip sessions already in SwiftData (confirmed/dismissed or already inserted)
            if preservedIDs.contains(session.id) { continue }
            if session.modelContext != nil { continue }

            // Skip if this session overlaps with an already-confirmed/dismissed one (except exercise)
            if session.type != .exercise {
                let overlapsPreserved = preservedSessions.contains { existing in
                    session.startTime < existing.endTime && session.endTime > existing.startTime
                }
                if overlapsPreserved { continue }
            }

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
