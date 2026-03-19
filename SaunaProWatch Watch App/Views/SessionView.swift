import SwiftUI

struct SessionView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        switch manager.state {
        case .idle:
            IdleView()
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
