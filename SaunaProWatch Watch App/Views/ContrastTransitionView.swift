import SwiftUI
import WatchKit

struct ContrastTransitionView: View {
    @Environment(WatchWorkoutManager.self) var manager
    @State private var countdown = 3

    private var nextPhase: String { manager.contrastNextPhase }
    private var isSaunaNext: Bool { nextPhase == "sauna" }
    private var phaseColor: Color { isSaunaNext ? .orange : .cyan }
    private var phaseIcon: String { isSaunaNext ? "flame.fill" : "snowflake" }
    private var phaseLabel: String { isSaunaNext ? "SAUNA" : "COLD" }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: phaseIcon)
                .font(.system(size: 40))
                .foregroundStyle(phaseColor)

            Text("Switching to")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(phaseLabel)
                .font(.title2.bold())
                .foregroundStyle(phaseColor)

            Text("\(countdown)")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(phaseColor)
                .contentTransition(.numericText())

            Button {
                skipCountdown()
            } label: {
                Text("TAP TO SKIP")
                    .font(.caption2)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            startCountdown()
        }
    }

    private func startCountdown() {
        countdown = 3
        WKInterfaceDevice.current().play(.click)

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            Task { @MainActor in
                countdown -= 1
                if countdown > 0 {
                    WKInterfaceDevice.current().play(.click)
                } else {
                    timer.invalidate()
                    completeTransition()
                }
            }
        }
    }

    private func skipCountdown() {
        completeTransition()
    }

    private func completeTransition() {
        if isSaunaNext {
            WKInterfaceDevice.current().play(.start)
        } else {
            WKInterfaceDevice.current().play(.notification)
        }
        manager.contrastTransitionComplete()
    }
}
