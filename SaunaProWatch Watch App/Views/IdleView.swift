import SwiftUI
import WatchKit

struct IdleView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Button {
                WKInterfaceDevice.current().play(.start)
                Task {
                    try? await manager.startSaunaSession()
                }
            } label: {
                Text("START SAUNA")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button {
                WKInterfaceDevice.current().play(.start)
                Task {
                    try? await manager.startContrastSession()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("CONTRAST")
                        .bold()
                    Image(systemName: "snowflake")
                        .foregroundStyle(.cyan)
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray.opacity(0.3))
        }
    }
}
