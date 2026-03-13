import SwiftUI

/// Heart rate benefit zones for sauna sessions, mapping HR ranges to therapeutic effects.
/// Based on sports science research on cardiovascular responses to passive heat exposure.
enum HRZone: CaseIterable {
    case warmUp        // Getting started, body adapting
    case lightHeat     // Relaxation, mild stress relief
    case cardiovascular // Active cardiovascular conditioning
    case deepHeat      // Peak therapeutic benefits
    case extreme       // Very high — consider stepping out

    /// The minimum BPM for this zone (inclusive)
    var minBPM: Double {
        switch self {
        case .warmUp: 60
        case .lightHeat: 90
        case .cardiovascular: 110
        case .deepHeat: 130
        case .extreme: 150
        }
    }

    /// The maximum BPM for this zone (exclusive, except extreme which is open-ended)
    var maxBPM: Double {
        switch self {
        case .warmUp: 90
        case .lightHeat: 110
        case .cardiovascular: 130
        case .deepHeat: 150
        case .extreme: 200
        }
    }

    var label: String {
        switch self {
        case .warmUp: "Warm-Up"
        case .lightHeat: "Light Heat"
        case .cardiovascular: "Cardio"
        case .deepHeat: "Deep Heat"
        case .extreme: "Extreme"
        }
    }

    var subtitle: String {
        switch self {
        case .warmUp: "Body adapting to heat"
        case .lightHeat: "Relaxation & stress relief"
        case .cardiovascular: "Cardiovascular conditioning"
        case .deepHeat: "Peak therapeutic benefits"
        case .extreme: "Consider stepping out"
        }
    }

    var bpmRange: String {
        switch self {
        case .extreme: "150+ bpm"
        default: "\(Int(minBPM))–\(Int(maxBPM)) bpm"
        }
    }

    var color: Color {
        switch self {
        case .warmUp: .green
        case .lightHeat: .yellow
        case .cardiovascular: .orange
        case .deepHeat: .red
        case .extreme: .purple
        }
    }

    var icon: String {
        switch self {
        case .warmUp: "flame"
        case .lightHeat: "flame.fill"
        case .cardiovascular: "heart.fill"
        case .deepHeat: "bolt.heart.fill"
        case .extreme: "exclamationmark.triangle.fill"
        }
    }

    /// Returns the zone for a given heart rate
    static func zone(for bpm: Double) -> HRZone {
        switch bpm {
        case ..<90: .warmUp
        case 90..<110: .lightHeat
        case 110..<130: .cardiovascular
        case 130..<150: .deepHeat
        default: .extreme
        }
    }

    /// Calculates time spent in each zone from an array of HR samples within a session window
    static func zoneBreakdown(samples: [(timestamp: Date, bpm: Double)]) -> [HRZone: TimeInterval] {
        guard samples.count > 1 else { return [:] }

        var breakdown: [HRZone: TimeInterval] = [:]
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }

        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]
            let duration = next.timestamp.timeIntervalSince(current.timestamp)

            // Skip gaps longer than 2 minutes (likely sensor dropout)
            guard duration < 120 else { continue }

            let zone = zone(for: current.bpm)
            breakdown[zone, default: 0] += duration
        }

        return breakdown
    }

    /// Returns the dominant (most time spent) zone
    static func dominantZone(from breakdown: [HRZone: TimeInterval]) -> HRZone? {
        breakdown.max(by: { $0.value < $1.value })?.key
    }
}
