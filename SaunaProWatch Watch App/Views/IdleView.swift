import SwiftUI
import WatchKit

struct IdleView: View {
    @Environment(WatchWorkoutManager.self) var manager

    var body: some View {
        if !manager.isAuthorized {
            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Setting up...")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView()
                    .tint(.orange)
            }
            .task {
                await manager.requestAuthorization()
            }
        } else {
            VStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    WKInterfaceDevice.current().play(.start)
                    manager.state = .starting
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
                    manager.state = .starting
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
}
