import SwiftUI
import Charts

struct HeartRateChartView: View {
    let samples: [HealthSample]
    let sessions: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate")
                .font(.headline)

            if samples.isEmpty {
                Text("No heart rate data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
            } else {
                Chart {
                    // Session highlight regions
                    ForEach(sessions) { session in
                        RectangleMark(
                            xStart: .value("Start", session.startTime),
                            xEnd: .value("End", session.endTime),
                            yStart: nil,
                            yEnd: nil
                        )
                        .foregroundStyle(session.type == .sauna ? Color.orange.opacity(0.15) : Color.cyan.opacity(0.15))
                    }

                    // HR line
                    ForEach(samples) { sample in
                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("BPM", sample.value)
                        )
                        .foregroundStyle(colorForHR(sample.value))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        AxisValueLabel(format: .dateTime.hour())
                        AxisGridLine()
                    }
                }
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    ForEach(sessions) { session in
                        HStack(spacing: 4) {
                            Image(systemName: session.type.icon)
                                .font(.caption2)
                                .foregroundStyle(session.type == .sauna ? .orange : .cyan)
                            Text(timeString(session.startTime))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func colorForHR(_ hr: Double) -> Color {
        if hr >= 120 { return .red }
        if hr >= 90 { return .orange }
        return .green
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let data = SampleDataProvider.generateDay(for: Date())
    let sessions = EventDetector().detectSessions(dayData: data)
    HeartRateChartView(samples: data.heartRateSamples, sessions: sessions)
        .padding()
        .preferredColorScheme(.dark)
}
