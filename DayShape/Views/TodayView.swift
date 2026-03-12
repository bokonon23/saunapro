import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse)

                Text("SaunaPro")
                    .font(.largeTitle.bold())

                Text("Track your sauna & cold plunge sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Connect to HealthKit to auto-detect sessions from your Apple Watch.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
}
