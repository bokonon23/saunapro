import SwiftUI

/// Heart rate benefit zones for cold plunge/cold exposure sessions.
/// Cold exposure physiology: initial shock spike → sympathetic activation → vagal adaptation → calm.
/// Based on cold water immersion research (Søberg et al., Huberman protocols).
enum ColdZone: CaseIterable {
    case shockResponse   // Initial gasp reflex, HR spikes sharply
    case sympathetic     // Fight-or-flight activation, elevated HR
    case adaptation      // Body beginning to adapt, HR settling
    case vagalTone       // Parasympathetic activation, calm focus
    case deepCalm        // Low HR, deep parasympathetic state

    /// The minimum BPM for this zone (inclusive)
    var minBPM: Double {
        switch self {
        case .deepCalm: 40
        case .vagalTone: 55
        case .adaptation: 70
        case .sympathetic: 90
        case .shockResponse: 110
        }
    }

    /// The maximum BPM for this zone (exclusive, except shock which is open-ended)
    var maxBPM: Double {
        switch self {
        case .deepCalm: 55
        case .vagalTone: 70
        case .adaptation: 90
        case .sympathetic: 110
        case .shockResponse: 200
        }
    }

    var label: String {
        switch self {
        case .shockResponse: "Cold Shock"
        case .sympathetic: "Activation"
        case .adaptation: "Adapting"
        case .vagalTone: "Vagal Tone"
        case .deepCalm: "Deep Calm"
        }
    }

    var subtitle: String {
        switch self {
        case .shockResponse: "Initial cold shock response — control your breathing"
        case .sympathetic: "Sympathetic nervous system active — norepinephrine release"
        case .adaptation: "Body adapting to cold — stay present"
        case .vagalTone: "Parasympathetic activation — building resilience"
        case .deepCalm: "Deep calm state — peak vagal tone benefit"
        }
    }

    var bpmRange: String {
        switch self {
        case .shockResponse: "110+ bpm"
        default: "\(Int(minBPM))–\(Int(maxBPM)) bpm"
        }
    }

    var color: Color {
        switch self {
        case .shockResponse: .red
        case .sympathetic: .orange
        case .adaptation: .yellow
        case .vagalTone: .cyan
        case .deepCalm: .blue
        }
    }

    var icon: String {
        switch self {
        case .shockResponse: "bolt.fill"
        case .sympathetic: "wind"
        case .adaptation: "arrow.down.heart"
        case .vagalTone: "brain.head.profile"
        case .deepCalm: "snowflake"
        }
    }

    /// Returns the cold zone for a given heart rate
    static func zone(for bpm: Double) -> ColdZone {
        switch bpm {
        case ..<55: .deepCalm
        case 55..<70: .vagalTone
        case 70..<90: .adaptation
        case 90..<110: .sympathetic
        default: .shockResponse
        }
    }

    /// Calculates time spent in each zone from an array of HR samples
    static func zoneBreakdown(samples: [(timestamp: Date, bpm: Double)]) -> [ColdZone: TimeInterval] {
        guard samples.count > 1 else { return [:] }

        var breakdown: [ColdZone: TimeInterval] = [:]
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }

        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]
            let duration = next.timestamp.timeIntervalSince(current.timestamp)

            // Skip gaps longer than 2 minutes (sensor dropout)
            guard duration < 120 else { continue }

            let zone = zone(for: current.bpm)
            breakdown[zone, default: 0] += duration
        }

        return breakdown
    }

    /// Returns the dominant (most time spent) zone
    static func dominantZone(from breakdown: [ColdZone: TimeInterval]) -> ColdZone? {
        breakdown.max(by: { $0.value < $1.value })?.key
    }
}
