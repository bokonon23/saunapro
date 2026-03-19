import SwiftUI
import WatchKit

struct ContrastSummaryView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Image(systemName: "snowflake")
                        .foregroundStyle(.cyan)
                }
                .font(.title3)

                Text("Contrast Complete")
                    .font(.headline)

                // Total time
                HStack {
                    Text("Total Time")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDuration(manager.elapsedSeconds))
                        .bold()
                }
                .font(.caption)

                // Rounds
                HStack {
                    Text("Rounds")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(manager.contrastRounds.count)")
                        .bold()
                }
                .font(.caption)

                Divider()

                // Per-round breakdown
                ForEach(Array(manager.contrastRounds.enumerated()), id: \.offset) { _, round in
                    HStack(spacing: 4) {
                        Image(systemName: round.phase == "sauna" ? "flame.fill" : "snowflake")
                            .font(.caption2)
                            .foregroundStyle(round.phase == "sauna" ? .orange : .cyan)

                        Text("R\(round.roundNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(formatDuration(round.durationSeconds))
                            .font(.caption2.bold())

                        Spacer()

                        if let peak = round.peakHR {
                            Text("\(Int(peak)) bpm")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Søberg badge
                if manager.completedSession?.endedOnCold == true {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Søberg — ended on cold")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
                }

                Divider()

                // Done button
                Button {
                    WKInterfaceDevice.current().play(.success)
                    if let session = manager.completedSession {
                        WatchConnectivityManager.shared.sendSession(session)
                    }
                    manager.reset()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal, 4)
        }
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}
