import Foundation
import FoundationModels

protocol AICoachingProvider: Sendable {
    func generateCoaching(sessionSummary: String) async throws -> String
}

struct FoundationModelProvider: AICoachingProvider {

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    nonisolated func generateCoaching(sessionSummary: String) async throws -> String {
        let session = LanguageModelSession(
            model: .default,
            instructions: """
                You are a concise sauna and cold plunge wellness coach. \
                Analyse the user's recent session data and provide 2-3 short, actionable coaching insights. \
                Reference the Huberman sauna protocol (57+ min/week across 2-7 sessions) and \
                Søberg cold exposure principle (end on cold for maximum norepinephrine and metabolic benefit) where relevant. \
                Be encouraging but honest. Keep your response under 150 words. Do not use bullet points.
                """
        )

        let response = try await session.respond(to: sessionSummary)
        return response.content
    }

    /// Build a summary string from recent sessions suitable for the AI prompt.
    static func buildSessionSummary(from sessions: [SessionRecord]) -> String {
        let therapy = sessions.filter { $0.type.isTherapy }
        guard !therapy.isEmpty else { return "No recent therapy sessions." }

        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = therapy.filter { $0.startTime >= weekAgo }

        let saunaCount = recent.filter { $0.type == .sauna }.count
        let coldCount = recent.filter { $0.type == .coldPlunge }.count
        let saunaMinutes = recent.filter { $0.type == .sauna }.reduce(0.0) { $0 + $1.durationMinutes }
        let coldMinutes = recent.filter { $0.type == .coldPlunge }.reduce(0.0) { $0 + $1.durationMinutes }

        let sequences = ContrastDetector.detectSequences(sessions: recent)
        let contrastCount = sequences.filter { $0.isFullContrast }.count

        var summary = "Past 7 days: \(saunaCount) sauna sessions (\(String(format: "%.0f", saunaMinutes)) min total), "
        summary += "\(coldCount) cold plunge sessions (\(String(format: "%.0f", coldMinutes)) min total). "
        summary += "\(contrastCount) contrast therapy sequences. "

        if let latest = recent.sorted(by: { $0.startTime > $1.startTime }).first {
            summary += "Most recent: \(latest.type.displayName), \(String(format: "%.0f", latest.durationMinutes)) min"
            if let peak = latest.peakHR, let baseline = latest.baselineHR {
                summary += ", peak HR \(String(format: "%.0f", peak)) (baseline \(String(format: "%.0f", baseline)))"
            }
            if let recovery = latest.recoveryMinutes {
                summary += ", recovery \(String(format: "%.0f", recovery)) min"
            }
            if let delta = latest.hrvDeltaPercent {
                summary += ", HRV change \(String(format: "%+.0f", delta))%"
            }
            summary += "."
        }

        let recoveries = recent.compactMap(\.recoveryMinutes)
        if recoveries.count >= 2 {
            let avg = recoveries.reduce(0, +) / Double(recoveries.count)
            summary += " Avg recovery time: \(String(format: "%.0f", avg)) min."
        }

        return summary
    }
}
