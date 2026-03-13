import SwiftUI
import WatchKit

struct ActiveSessionView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        VStack(spacing: 8) {
            // Elapsed time
            Text(formatTime(manager.elapsedSeconds))
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)

            // Current heart rate
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("\(Int(manager.currentHeartRate))")
                    .font(.title2.bold())
                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Peak HR
            if manager.peakHeartRate > 0 {
                HStack(spacing: 4) {
                    Text("Peak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Int(manager.peakHeartRate))")
                        .font(.caption.bold())
                }
            }

            Spacer()

            // Stop button
            Button {
                WKInterfaceDevice.current().play(.stop)
                manager.stopSession()
            } label: {
                Text("STOP")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
