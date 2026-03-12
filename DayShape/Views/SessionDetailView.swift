import SwiftUI
import SwiftData
import Charts

struct SessionDetailView: View {
    @Bindable var session: SessionRecord
    let dayData: DayData?
    @State private var notes: String
    @Environment(\.modelContext) private var modelContext

    init(session: SessionRecord, dayData: DayData?) {
        self.session = session
        self.dayData = dayData
        self._notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session header
                HStack {
                    Image(systemName: session.type.icon)
                        .font(.largeTitle)
                        .foregroundStyle(session.type == .sauna ? .orange : .cyan)
                    VStack(alignment: .leading) {
                        Text(session.type.displayName)
                            .font(.title2.bold())
                        Text(dateTimeString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // Zoomed HR chart
                if let dayData {
                    zoomedChart(dayData: dayData)
                        .padding(.horizontal)
                }

                // Key metrics grid
                metricsGrid
                    .padding(.horizontal)

                // Temperature section
                if session.waterTemperature != nil || session.wristTempBefore != nil {
                    temperatureSection
                        .padding(.horizontal)
                }

                // HRV section
                if session.preSessionHRV != nil || session.postSessionHRV != nil {
                    hrvSection
                        .padding(.horizontal)
                }

                // Notes
                notesSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Zoomed HR Chart

    @ViewBuilder
    private func zoomedChart(dayData: DayData) -> some View {
        let windowStart = session.startTime.addingTimeInterval(-60 * 60)
        let windowEnd = session.endTime.addingTimeInterval(30 * 60)
        let windowedSamples = dayData.heartRateSamples.filter {
            $0.timestamp >= windowStart && $0.timestamp <= windowEnd
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate Detail")
                .font(.headline)

            Chart {
                // Session zone
                RectangleMark(
                    xStart: .value("Start", session.startTime),
                    xEnd: .value("End", session.endTime),
                    yStart: nil,
                    yEnd: nil
                )
                .foregroundStyle(session.type == .sauna ? Color.orange.opacity(0.15) : Color.cyan.opacity(0.15))

                // Baseline line
                if let baseline = session.baselineHR {
                    RuleMark(y: .value("Baseline", baseline))
                        .foregroundStyle(.green.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))

                    // Recovery threshold
                    RuleMark(y: .value("Recovery", baseline + 10))
                        .foregroundStyle(.yellow.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
                }

                // HR data
                ForEach(windowedSamples) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("BPM", sample.value)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // Peak marker
                if let peakTime = session.peakTime, let peakHR = session.peakHR {
                    PointMark(
                        x: .value("Peak", peakTime),
                        y: .value("BPM", peakHR)
                    )
                    .foregroundStyle(.orange)
                    .symbolSize(80)
                    .annotation(position: .top) {
                        Text(String(format: "%.0f", peakHR))
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .minute, count: 15)) { value in
                    AxisValueLabel(format: .dateTime.hour().minute())
                    AxisGridLine()
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Metrics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(label: "Duration", value: String(format: "%.0f min", session.durationMinutes), icon: "timer", color: .blue)

                if let peak = session.peakHR {
                    MetricTile(label: "Peak HR", value: String(format: "%.0f bpm", peak), icon: "heart.fill", color: .orange)
                }

                if let baseline = session.baselineHR {
                    MetricTile(label: "Baseline HR", value: String(format: "%.0f bpm", baseline), icon: "heart", color: .green)
                }

                if let elevation = session.elevationAboveBaseline {
                    MetricTile(label: "Elevation", value: String(format: "+%.0f bpm", elevation), icon: "arrow.up", color: .red)
                }

                if let recovery = session.recoveryMinutes {
                    MetricTile(label: "Recovery Time", value: String(format: "%.0f min", recovery), icon: "arrow.down.heart", color: .green)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Temperature

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperature")
                .font(.headline)

            HStack(spacing: 20) {
                if let waterTemp = session.waterTemperature {
                    VStack {
                        Image(systemName: "water.waves")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                        Text(String(format: "%.1f°C", waterTemp))
                            .font(.title3.bold())
                        Text("Water")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - HRV

    private var hrvSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HRV Impact")
                .font(.headline)

            HStack(spacing: 24) {
                if let pre = session.preSessionHRV {
                    VStack {
                        Text(String(format: "%.0f ms", pre))
                            .font(.title3.bold())
                        Text("Pre-session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if session.preSessionHRV != nil && session.postSessionHRV != nil {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                }

                if let post = session.postSessionHRV {
                    VStack {
                        Text(String(format: "%.0f ms", post))
                            .font(.title3.bold())
                            .foregroundStyle(post < (session.preSessionHRV ?? post) ? .yellow : .green)
                        Text("Post-session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let delta = session.hrvDeltaPercent {
                    VStack {
                        Text("\(delta >= 0 ? "+" : "")\(String(format: "%.0f", delta))%")
                            .font(.title3.bold())
                            .foregroundStyle(delta >= 0 ? .green : .yellow)
                        Text("Change")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            TextField("Add notes (supplements, temperature, seat position...)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .onChange(of: notes) {
                    session.notes = notes.isEmpty ? nil : notes
                    try? modelContext.save()
                }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private var dateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: session.startTime)) – \(DateFormatter.timeOnly.string(from: session.endTime))"
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}
