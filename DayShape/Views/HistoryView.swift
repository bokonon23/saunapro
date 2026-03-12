import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "calendar.badge.clock",
                description: Text("Past days will appear here once you start importing health data.")
            )
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
