import SwiftUI
import WatchKit

struct IdleView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Button {
                WKInterfaceDevice.current().play(.start)
                Task {
                    try? await manager.startSaunaSession()
                }
            } label: {
                Text("START\nSAUNA")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}
