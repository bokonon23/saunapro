import Foundation
import SwiftUI

struct ContrastSequence: Identifiable {
    let id: UUID
    let sessions: [SessionRecord]

    var rounds: Int { sessions.count }

    var totalDurationMinutes: Double {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var hasSauna: Bool {
        sessions.contains { $0.type == .sauna }
    }

    var hasCold: Bool {
        sessions.contains { $0.type == .coldPlunge }
    }

    var isFullContrast: Bool {
        hasSauna && hasCold
    }

    var endedOnCold: Bool {
        sessions.last?.type == .coldPlunge
    }

    var startTime: Date {
        sessions.first?.startTime ?? .distantPast
    }

    var endTime: Date {
        sessions.last?.endTime ?? .distantPast
    }

    var totalRestMinutes: Double {
        guard sessions.count > 1 else { return 0 }
        var rest: Double = 0
        for i in 1..<sessions.count {
            let gap = sessions[i].startTime.timeIntervalSince(sessions[i - 1].endTime) / 60.0
            if gap > 0 { rest += gap }
        }
        return rest
    }

    var restGaps: [Double] {
        guard sessions.count > 1 else { return [] }
        return (1..<sessions.count).map { i in
            max(0, sessions[i].startTime.timeIntervalSince(sessions[i - 1].endTime) / 60.0)
        }
    }

    var averagePeakHR: Double? {
        let peaks = sessions.compactMap(\.peakHR)
        guard !peaks.isEmpty else { return nil }
        return peaks.reduce(0, +) / Double(peaks.count)
    }
}

struct ContrastDetector {
    static let maxGapMinutes: Double = 30

    /// Group sessions into contrast therapy sequences.
    /// Sessions within 30 min of each other on the same day form a sequence (2+ sessions required).
    static func detectSequences(sessions: [SessionRecord]) -> [ContrastSequence] {
        let therapy = sessions
            .filter { $0.type.isTherapy && $0.sessionStatus != .dismissed }
            .sorted { $0.startTime < $1.startTime }

        guard therapy.count >= 2 else { return [] }

        var sequences: [ContrastSequence] = []
        var currentGroup: [SessionRecord] = [therapy[0]]

        for i in 1..<therapy.count {
            let gap = therapy[i].startTime.timeIntervalSince(therapy[i - 1].endTime) / 60.0
            if gap <= maxGapMinutes && gap >= 0 {
                currentGroup.append(therapy[i])
            } else {
                if currentGroup.count >= 2 {
                    let groupId = currentGroup.first?.contrastGroupId ?? UUID()
                    sequences.append(ContrastSequence(id: groupId, sessions: currentGroup))
                }
                currentGroup = [therapy[i]]
            }
        }

        if currentGroup.count >= 2 {
            let groupId = currentGroup.first?.contrastGroupId ?? UUID()
            sequences.append(ContrastSequence(id: groupId, sessions: currentGroup))
        }

        return sequences
    }

    /// Assign contrastGroupId to sessions that form sequences.
    static func assignGroupIds(sessions: [SessionRecord]) {
        let sequences = detectSequences(sessions: sessions)
        for sequence in sequences {
            for session in sequence.sessions {
                if session.contrastGroupId == nil {
                    session.contrastGroupId = sequence.id
                }
            }
        }
    }
}
