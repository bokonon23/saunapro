import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \SessionRecord.startTime, order: .reverse) private var allSessions: [SessionRecord]

    var body: some View {
        NavigationStack {
            if allSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "calendar.badge.clock",
                    description: Text("Your sauna and cold plunge history will appear here once sessions are detected.")
                )
                .navigationTitle("History")
            } else {
                List {
                    ForEach(groupedByDate, id: \.key) { dateKey, sessions in
                        Section(dateKey) {
                            ForEach(sessions) { session in
                                HStack {
                                    Image(systemName: session.type.icon)
                                        .foregroundStyle(session.type == .sauna ? .orange : .cyan)

                                    VStack(alignment: .leading) {
                                        Text(session.type.displayName)
                                            .font(.subheadline.bold())
                                        Text(String(format: "%.0f min", session.durationMinutes))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if let peak = session.peakHR {
                                        Text(String(format: "%.0f bpm", peak))
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("History")
            }
        }
    }

    private var groupedByDate: [(key: String, value: [SessionRecord])] {
        Dictionary(grouping: allSessions, by: \.dateKey)
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, value: $0.value) }
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
        .modelContainer(for: SessionRecord.self, inMemory: true)
}
