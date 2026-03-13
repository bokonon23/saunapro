import SwiftUI
import WatchKit

struct SummaryView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Session icon
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Session Complete")
                    .font(.headline)

                // Duration
                HStack {
                    Text("Duration")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDuration(manager.elapsedSeconds))
                        .bold()
                }
                .font(.caption)

                // Peak HR
                if manager.peakHeartRate > 0 {
                    HStack {
                        Text("Peak HR")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(manager.peakHeartRate)) BPM")
                            .bold()
                    }
                    .font(.caption)
                }

                // Avg HR
                if manager.averageHeartRate > 0 {
                    HStack {
                        Text("Avg HR")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(manager.averageHeartRate)) BPM")
                            .bold()
                    }
                    .font(.caption)
                }

                // Cold plunge info
                if manager.coldPlungeMarked {
                    HStack {
                        Image(systemName: "snowflake")
                            .foregroundStyle(.cyan)
                        Text("Cold Plunge")
                        Spacer()
                        Text(formatDuration(manager.coldPlungeElapsedSeconds))
                            .bold()
                    }
                    .font(.caption)
                }

                Divider()

                // Mark cold plunge button (only if not already done)
                if !manager.coldPlungeMarked {
                    Button {
                        WKInterfaceDevice.current().play(.start)
                        manager.startColdPlunge()
                    } label: {
                        Label("Cold Plunge", systemImage: "snowflake")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }

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
