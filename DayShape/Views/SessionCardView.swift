import SwiftUI

struct SessionCardView: View {
    let session: SessionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: session.type.icon)
                    .font(.title2)
                    .foregroundStyle(session.type == .sauna ? .orange : .cyan)

                VStack(alignment: .leading) {
                    Text(session.type.displayName)
                        .font(.headline)
                    Text(timeRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(String(format: "%.0f min", session.durationMinutes))
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }

            // Metrics row
            HStack(spacing: 16) {
                if let peak = session.peakHR {
                    MetricPill(label: "Peak HR", value: String(format: "%.0f", peak), unit: "bpm", color: .orange)
                }

                if let elevation = session.elevationAboveBaseline {
                    MetricPill(label: "Elevation", value: String(format: "+%.0f", elevation), unit: "bpm", color: .red)
                }

                if let recovery = session.recoveryMinutes {
                    MetricPill(label: "Recovery", value: String(format: "%.0f", recovery), unit: "min", color: .green)
                }

                if let waterTemp = session.waterTemperature {
                    MetricPill(label: "Water", value: String(format: "%.1f", waterTemp), unit: "°C", color: .cyan)
                }
            }

            // HRV delta
            if let delta = session.hrvDeltaPercent {
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                    Text("HRV \(delta >= 0 ? "+" : "")\(String(format: "%.0f", delta))% post-session")
                        .font(.caption)
                }
                .foregroundStyle(delta >= 0 ? .green : .yellow)
            }

            // Notes preview
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: session.startTime)) – \(formatter.string(from: session.endTime))"
    }
}

struct MetricPill: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SessionCardView(session: SessionRecord(
        type: .sauna,
        startTime: Date().addingTimeInterval(-900),
        endTime: Date(),
        peakTime: Date().addingTimeInterval(-300),
        baselineHR: 62,
        peakHR: 138,
        recoveryMinutes: 8,
        preSessionHRV: 45,
        postSessionHRV: 28
    ))
    .padding()
    .preferredColorScheme(.dark)
}
