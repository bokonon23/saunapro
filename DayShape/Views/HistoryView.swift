import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \SessionRecord.startTime, order: .reverse) private var allSessions: [SessionRecord]
    @State private var selectedSession: SessionRecord?
    @State private var dayDataForSession: DayData?
    @State private var isLoadingDetail = false

    var body: some View {
        NavigationStack {
            if allSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "calendar.badge.clock",
                    description: Text("Your sauna and cold plunge history will appear here once sessions are detected.\n\nUse Day View to browse past days.")
                )
                .navigationTitle("History")
            } else {
                List {
                    ForEach(groupedByDate, id: \.key) { dateKey, sessions in
                        Section {
                            let sequences = ContrastDetector.detectSequences(sessions: sessions)
                            let sequenceIds = Set(sequences.flatMap { $0.sessions.map(\.id) })
                            let standalone = sessions.filter { !sequenceIds.contains($0.id) }

                            ForEach(sequences) { sequence in
                                NavigationLink(value: sequence.sessions.first!) {
                                    HStack {
                                        HStack(spacing: 2) {
                                            Image(systemName: "flame.fill")
                                                .foregroundStyle(.orange)
                                            Image(systemName: "snowflake")
                                                .foregroundStyle(.cyan)
                                        }
                                        .font(.caption)
                                        .frame(width: 30)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Contrast Therapy")
                                                .font(.subheadline.bold())
                                            HStack(spacing: 8) {
                                                Text(timeString(sequence.startTime))
                                                Text("·")
                                                Text("\(sequence.rounds) rounds")
                                                Text("·")
                                                Text(String(format: "%.0f min", sequence.totalDurationMinutes))
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if sequence.endedOnCold {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }

                            ForEach(standalone) { session in
                                NavigationLink(value: session) {
                                    HStack {
                                        Image(systemName: session.type.icon)
                                            .font(.title3)
                                            .foregroundStyle(session.type.color)
                                            .frame(width: 30)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(session.type.displayName)
                                                .font(.subheadline.bold())

                                            HStack(spacing: 8) {
                                                Text(timeString(session.startTime))
                                                Text("·")
                                                Text(String(format: "%.0f min", session.durationMinutes))
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            if let peak = session.peakHR {
                                                Text(String(format: "%.0f bpm", peak))
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.orange)
                                            }
                                            if let elevation = session.elevationAboveBaseline {
                                                Text(String(format: "+%.0f", elevation))
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        } header: {
                            Text(formattedDateHeader(dateKey))
                                .font(.subheadline.bold())
                        }
                    }
                }
                .navigationTitle("History")
                .navigationDestination(for: SessionRecord.self) { session in
                    HistoryDetailLoader(session: session)
                }
            }
        }
    }

    private var groupedByDate: [(key: String, value: [SessionRecord])] {
        Dictionary(grouping: allSessions, by: \.dateKey)
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, value: $0.value) }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedDateHeader(_ dateKey: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateKey) else { return dateKey }

        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEEE d MMMM"
        return outputFormatter.string(from: date)
    }
}

/// Loads day data for a history session so the detail view can show the HR chart.
struct HistoryDetailLoader: View {
    let session: SessionRecord
    @State private var dayData: DayData?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading session data...")
            } else {
                SessionDetailView(session: session, dayData: dayData)
            }
        }
        .task {
            let manager = HealthKitManager.shared
            if manager.isAvailable {
                do {
                    try await manager.requestAuthorization()
                    dayData = try await manager.fetchDayData(for: session.startTime)
                } catch {
                    // No day data available — detail will show without chart
                }
            }
            isLoading = false
        }
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
        .modelContainer(for: SessionRecord.self, inMemory: true)
}
