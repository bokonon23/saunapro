import SwiftUI

struct SessionView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        switch manager.state {
        case .idle:
            IdleView()
        case .starting:
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.orange)
                Text("Starting session...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .running:
            ActiveSessionView()
        case .coldPlunge:
            ColdPlungeView()
        case .summary:
            SummaryView()
        case .contrastSauna:
            ContrastPhaseView(phase: "sauna")
        case .contrastCold:
            ContrastPhaseView(phase: "cold")
        case .contrastTransition:
            ContrastTransitionView()
        case .contrastSummary:
            ContrastSummaryView()
        }
    }
}
