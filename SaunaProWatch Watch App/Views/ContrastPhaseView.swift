import SwiftUI
import WatchKit

struct ContrastPhaseView: View {
    @Environment(WatchWorkoutManager.self) var manager

    let phase: String // "sauna" or "cold"

    private var isSauna: Bool { phase == "sauna" }
    private var phaseColor: Color { isSauna ? .orange : .cyan }
    private var phaseIcon: String { isSauna ? "flame.fill" : "snowflake" }
    private var phaseLabel: String { isSauna ? "SAUNA" : "COLD" }

    var body: some View {
        VStack(spacing: 6) {
            // Phase header
            HStack(spacing: 4) {
                Image(systemName: phaseIcon)
                    .foregroundStyle(phaseColor)
                Text(phaseLabel)
                    .font(.caption.bold())
                    .foregroundStyle(phaseColor)
                Text("· Round \(manager.contrastRoundNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Phase timer
            Text(formatTime(manager.contrastPhaseElapsedSeconds))
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundStyle(phaseColor)

            // Heart rate
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("\(Int(manager.currentHeartRate))")
                    .font(.title3.bold())
                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Switch phase
                Button {
                    WKInterfaceDevice.current().play(.click)
                    if isSauna {
                        manager.endContrastSaunaPhase(switchToCold: true)
                    } else {
                        manager.endContrastColdPhase(switchToSauna: true)
                    }
                } label: {
                    Label("SWITCH", systemImage: isSauna ? "snowflake" : "flame.fill")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isSauna ? .cyan : .orange)

                // End session
                Button {
                    WKInterfaceDevice.current().play(.stop)
                    if isSauna {
                        manager.endContrastSaunaPhase(switchToCold: false)
                    } else {
                        manager.endContrastColdPhase(switchToSauna: false)
                    }
                } label: {
                    Text("END")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
