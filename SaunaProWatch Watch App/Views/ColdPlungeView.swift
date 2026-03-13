import SwiftUI
import WatchKit

struct ColdPlungeView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "snowflake")
                .font(.system(size: 30))
                .foregroundStyle(.cyan)

            Text("Cold Plunge")
                .font(.headline)
                .foregroundStyle(.cyan)

            // Timer
            Text(formatTime(manager.coldPlungeElapsedSeconds))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan)

            // Current HR
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Text("\(Int(manager.currentHeartRate)) BPM")
                    .font(.caption)
            }

            Spacer()

            Button {
                WKInterfaceDevice.current().play(.stop)
                manager.stopColdPlunge()
            } label: {
                Text("STOP")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
