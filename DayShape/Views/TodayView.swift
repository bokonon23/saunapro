import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @State private var dataManager = DataManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if dataManager.isLoading {
                        ProgressView("Loading health data...")
                            .padding(.top, 60)
                    } else if let dayData = dataManager.dayData {
                        if dataManager.isUsingSimulatorData {
                            Label("Sample data (Apple Watch Ultra sim)", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .padding(.horizontal)
                        }

                        HeartRateChartView(samples: dayData.heartRateSamples, sessions: dataManager.sessions)
                            .padding(.horizontal)

                        if dataManager.sessions.isEmpty {
                            ContentUnavailableView(
                                "No Sessions Detected",
                                systemImage: "flame",
                                description: Text("No sauna or cold plunge sessions found today.")
                            )
                            .padding(.top, 20)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today's Sessions")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(dataManager.sessions) { session in
                                    NavigationLink(value: session) {
                                        SessionCardView(session: session)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 24) {
                            Spacer().frame(height: 60)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse)
                            Text("SaunaPro")
                                .font(.largeTitle.bold())
                            Text("Track your sauna & cold plunge sessions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Today")
            .navigationDestination(for: SessionRecord.self) { session in
                SessionDetailView(session: session, dayData: dataManager.dayData)
            }
            .refreshable {
                await dataManager.loadToday()
            }
            .task {
                await dataManager.loadToday()
            }
        }
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
        .modelContainer(for: SessionRecord.self, inMemory: true)
}
