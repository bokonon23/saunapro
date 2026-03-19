import SwiftUI

struct ContrastSequenceCardView: View {
    let sequence: ContrastSequence

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Image(systemName: "snowflake")
                        .foregroundStyle(.cyan)
                }
                .font(.title2)

                VStack(alignment: .leading) {
                    Text("Contrast Therapy")
                        .font(.headline)
                    Text("\(sequence.rounds) rounds · \(timeRange)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(String(format: "%.0f min", sequence.totalDurationMinutes + sequence.totalRestMinutes))
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }

            // Session timeline
            sessionTimeline

            // Metrics row
            HStack(spacing: 16) {
                MetricPill(
                    label: "Active",
                    value: String(format: "%.0f", sequence.totalDurationMinutes),
                    unit: "min",
                    color: .orange
                )
                MetricPill(
                    label: "Rest",
                    value: String(format: "%.0f", sequence.totalRestMinutes),
                    unit: "min",
                    color: .secondary
                )
                if let avgPeak = sequence.averagePeakHR {
                    MetricPill(
                        label: "Avg Peak",
                        value: String(format: "%.0f", avgPeak),
                        unit: "bpm",
                        color: .red
                    )
                }
            }

            // Soberg principle badge
            if sequence.endedOnCold {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Soberg Principle — ended on cold")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sessionTimeline: some View {
        HStack(spacing: 3) {
            ForEach(Array(sequence.sessions.enumerated()), id: \.element.id) { index, session in
                // Session block
                RoundedRectangle(cornerRadius: 4)
                    .fill(session.type.color.opacity(0.8))
                    .frame(height: 24)
                    .overlay {
                        HStack(spacing: 2) {
                            Image(systemName: session.type.icon)
                                .font(.system(size: 9))
                            Text(String(format: "%.0fm", session.durationMinutes))
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                    }

                // Rest gap between sessions
                if index < sequence.sessions.count - 1 {
                    let gap = sequence.restGaps[index]
                    if gap > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.gray.opacity(0.3))
                            .frame(width: 20, height: 24)
                            .overlay {
                                Text(String(format: "%.0f", gap))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
            }
        }
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: sequence.startTime)) – \(formatter.string(from: sequence.endTime))"
    }
}
