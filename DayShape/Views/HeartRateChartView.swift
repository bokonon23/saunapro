import SwiftUI
import Charts

struct HeartRateChartView: View {
    let samples: [HealthSample]
    let sessions: [SessionRecord]

    @State private var selectedSample: HealthSample?
    @State private var rawSelectedDate: Date?

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
                // Selection info bar
                if let sample = selectedSample {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(fullTimeString(sample.timestamp))
                                .font(.subheadline.monospacedDigit())
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(colorForHR(sample.value))
                            Text("\(Int(sample.value)) BPM")
                                .font(.subheadline.bold())
                                .foregroundStyle(colorForHR(sample.value))
                        }

                        Spacer()

                        // Show if this point is inside a detected session
                        if let session = sessionAt(sample.timestamp) {
                            HStack(spacing: 3) {
                                Image(systemName: session.type.icon)
                                    .font(.caption2)
                                Text(session.type.displayName)
                                    .font(.caption2)
                            }
                            .foregroundStyle(session.type.color)
                        }
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                }

                Chart {
                    // Session highlight regions
                    ForEach(sessions) { session in
                        RectangleMark(
                            xStart: .value("Start", session.startTime),
                            xEnd: .value("End", session.endTime),
                            yStart: nil,
                            yEnd: nil
                        )
                        .foregroundStyle(session.type.color.opacity(0.15))
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

                    // Selection indicator
                    if let sample = selectedSample {
                        RuleMark(x: .value("Selected", sample.timestamp))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                        PointMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("BPM", sample.value)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(60)
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
                .chartXSelection(value: $rawSelectedDate)
                .frame(height: 200)
                .onChange(of: rawSelectedDate) { _, newDate in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        if let date = newDate {
                            selectedSample = nearestSample(to: date)
                        } else {
                            selectedSample = nil
                        }
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    ForEach(sessions) { session in
                        HStack(spacing: 4) {
                            Image(systemName: session.type.icon)
                                .font(.caption2)
                                .foregroundStyle(session.type.color)
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

    // MARK: - Helpers

    private func nearestSample(to date: Date) -> HealthSample? {
        samples.min(by: {
            abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
        })
    }

    private func sessionAt(_ date: Date) -> SessionRecord? {
        sessions.first { session in
            date >= session.startTime && date <= session.endTime
        }
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

    private func fullTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
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
