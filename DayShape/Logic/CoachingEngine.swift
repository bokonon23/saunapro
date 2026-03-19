import Foundation
import SwiftUI

struct CoachingInsight: Identifiable {
    let id = UUID()
    let category: InsightCategory
    let title: String
    let body: String
    let icon: String
    let color: Color
    let priority: Int
    let isPremium: Bool

    init(category: InsightCategory, title: String, body: String, icon: String, color: Color, priority: Int, isPremium: Bool = false) {
        self.category = category
        self.title = title
        self.body = body
        self.icon = icon
        self.color = color
        self.priority = priority
        self.isPremium = isPremium
    }
}

enum InsightCategory: String {
    case sessionQuality
    case weeklyRecap
    case `protocol`
    case recovery
    case streak
    case contrast
    case aiCoaching
}

struct CoachingEngine {

    static func generateInsights(from sessions: [SessionRecord]) -> [CoachingInsight] {
        let confirmed = sessions.filter { $0.sessionStatus == .confirmed || $0.sessionStatus == .detected }
        guard !confirmed.isEmpty else { return [] }

        var insights: [CoachingInsight] = []

        insights.append(contentsOf: sessionQualityInsights(sessions: confirmed))
        insights.append(contentsOf: weeklyRecapInsights(sessions: confirmed))
        insights.append(contentsOf: protocolInsights(sessions: confirmed))
        insights.append(contentsOf: recoveryInsights(sessions: confirmed))
        insights.append(contentsOf: streakInsights(sessions: confirmed))
        insights.append(contentsOf: contrastInsights(sessions: confirmed))

        return insights.sorted { $0.priority > $1.priority }
    }

    // MARK: - Session Quality

    private static func sessionQualityInsights(sessions: [SessionRecord]) -> [CoachingInsight] {
        guard let latest = sessions.sorted(by: { $0.startTime > $1.startTime }).first,
              latest.type.isTherapy else { return [] }

        var insights: [CoachingInsight] = []

        if let peak = latest.peakHR, let baseline = latest.baselineHR, baseline > 0 {
            let ratio = peak / baseline
            if ratio >= 2.0 {
                insights.append(CoachingInsight(
                    category: .sessionQuality,
                    title: "Strong Session",
                    body: "Your peak HR reached \(String(format: "%.0f", ratio))x your baseline — that's a high-intensity session with maximum cardiovascular benefit.",
                    icon: "bolt.heart.fill",
                    color: .orange,
                    priority: 90
                ))
            } else if ratio >= 1.6 {
                insights.append(CoachingInsight(
                    category: .sessionQuality,
                    title: "Good Session",
                    body: "Your HR elevated to \(String(format: "%.0f", ratio))x baseline. You hit the sweet spot for cardiovascular conditioning.",
                    icon: "heart.fill",
                    color: .green,
                    priority: 80
                ))
            }
        }

        if let recovery = latest.recoveryMinutes {
            let previousRecoveries = sessions
                .filter { $0.id != latest.id && $0.recoveryMinutes != nil }
                .prefix(5)
                .compactMap(\.recoveryMinutes)

            if !previousRecoveries.isEmpty {
                let avgPrevious = previousRecoveries.reduce(0, +) / Double(previousRecoveries.count)
                if recovery < avgPrevious * 0.8 {
                    insights.append(CoachingInsight(
                        category: .sessionQuality,
                        title: "Faster Recovery",
                        body: "You recovered in \(String(format: "%.0f", recovery)) min vs your average of \(String(format: "%.0f", avgPrevious)) min. Your cardiovascular fitness is improving.",
                        icon: "arrow.down.heart.fill",
                        color: .green,
                        priority: 85
                    ))
                }
            }
        }

        return insights
    }

    // MARK: - Weekly Recap

    private static func weeklyRecapInsights(sessions: [SessionRecord]) -> [CoachingInsight] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) else { return [] }

        let thisWeek = sessions.filter { $0.startTime >= weekAgo && $0.type.isTherapy }
        let lastWeek = sessions.filter { $0.startTime >= twoWeeksAgo && $0.startTime < weekAgo && $0.type.isTherapy }

        guard !thisWeek.isEmpty else { return [] }

        let thisWeekMinutes = thisWeek.reduce(0.0) { $0 + $1.durationMinutes }

        var body = "\(thisWeek.count) session\(thisWeek.count == 1 ? "" : "s") this week totalling \(String(format: "%.0f", thisWeekMinutes)) minutes."

        if !lastWeek.isEmpty {
            let diff = thisWeek.count - lastWeek.count
            if diff > 0 {
                body += " That's \(diff) more than last week."
            } else if diff < 0 {
                body += " That's \(abs(diff)) fewer than last week."
            } else {
                body += " Same frequency as last week — nice consistency."
            }
        }

        return [CoachingInsight(
            category: .weeklyRecap,
            title: "Weekly Recap",
            body: body,
            icon: "chart.bar.fill",
            color: .blue,
            priority: 70
        )]
    }

    // MARK: - Protocol Tips

    private static func protocolInsights(sessions: [SessionRecord]) -> [CoachingInsight] {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return [] }

        var insights: [CoachingInsight] = []

        // Huberman protocol: 57+ min sauna per week across 2-7 sessions
        let weeklySauna = sessions.filter { $0.startTime >= weekAgo && $0.type == .sauna }
        let saunaMinutes = weeklySauna.reduce(0.0) { $0 + $1.durationMinutes }

        if saunaMinutes > 0 && saunaMinutes < 57 {
            let remaining = 57 - saunaMinutes
            insights.append(CoachingInsight(
                category: .protocol,
                title: "Huberman Protocol",
                body: "\(String(format: "%.0f", saunaMinutes)) of 57 min sauna this week. \(String(format: "%.0f", remaining)) more minutes to hit the research-backed target for longevity benefits.",
                icon: "target",
                color: .purple,
                priority: 75
            ))
        } else if saunaMinutes >= 57 {
            insights.append(CoachingInsight(
                category: .protocol,
                title: "Huberman Target Hit",
                body: "You've completed \(String(format: "%.0f", saunaMinutes)) min of sauna this week — exceeding the 57 min target linked to cardiovascular and longevity benefits.",
                icon: "star.fill",
                color: .yellow,
                priority: 80
            ))
        }

        // Soberg principle: end on cold for maximum metabolic benefit
        let todaySessions = sessions.filter { calendar.isDateInToday($0.startTime) && $0.type.isTherapy }
        let sequences = ContrastDetector.detectSequences(sessions: todaySessions)
        let notEndedOnCold = sequences.filter { !$0.endedOnCold }
        if !notEndedOnCold.isEmpty {
            insights.append(CoachingInsight(
                category: .protocol,
                title: "Soberg Tip",
                body: "Try ending your contrast session on cold exposure. Research shows finishing on cold maximises norepinephrine release and metabolic activation.",
                icon: "snowflake",
                color: .cyan,
                priority: 65
            ))
        }

        return insights
    }

    // MARK: - Recovery

    private static func recoveryInsights(sessions: [SessionRecord]) -> [CoachingInsight] {
        let calendar = Calendar.current
        guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()),
              let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return [] }

        let recentHRV = sessions
            .filter { $0.startTime >= oneWeekAgo && $0.hrvDeltaPercent != nil }
            .compactMap(\.hrvDeltaPercent)

        let previousHRV = sessions
            .filter { $0.startTime >= twoWeeksAgo && $0.startTime < oneWeekAgo && $0.hrvDeltaPercent != nil }
            .compactMap(\.hrvDeltaPercent)

        guard !recentHRV.isEmpty, !previousHRV.isEmpty else { return [] }

        let recentAvg = recentHRV.reduce(0, +) / Double(recentHRV.count)
        let previousAvg = previousHRV.reduce(0, +) / Double(previousHRV.count)

        if recentAvg > previousAvg + 5 {
            return [CoachingInsight(
                category: .recovery,
                title: "HRV Improving",
                body: "Your post-session HRV response has improved over the past week. This suggests your body is adapting well to your heat/cold routine.",
                icon: "waveform.path.ecg",
                color: .green,
                priority: 72
            )]
        } else if recentAvg < previousAvg - 10 {
            return [CoachingInsight(
                category: .recovery,
                title: "Recovery Check",
                body: "Your post-session HRV has dipped compared to last week. Consider a lighter session or extra rest day to support recovery.",
                icon: "bed.double.fill",
                color: .yellow,
                priority: 78
            )]
        }

        return []
    }

    // MARK: - Streaks

    private static func streakInsights(sessions: [SessionRecord]) -> [CoachingInsight] {
        let calendar = Calendar.current
        let therapySessions = sessions.filter { $0.type.isTherapy }
        guard !therapySessions.isEmpty else { return [] }

        // Calculate streak: consecutive days with at least one therapy session
        let sessionDays = Set(therapySessions.map { calendar.startOfDay(for: $0.startTime) })
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while sessionDays.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        // Also check if yesterday was the last session day (streak still alive if today hasn't had a session yet)
        if streak == 0 {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
            checkDate = yesterday
            while sessionDays.contains(checkDate) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            }
        }

        guard streak >= 2 else { return [] }

        return [CoachingInsight(
            category: .streak,
            title: "\(streak)-Day Streak",
            body: "You've had therapy sessions \(streak) days in a row. Consistency is the key to long-term benefits.",
            icon: "flame",
            color: .orange,
            priority: 60
        )]
    }

    // MARK: - Contrast Therapy

    private static func contrastInsights(sessions: [SessionRecord]) -> [CoachingInsight] {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return [] }

        let recentSessions = sessions.filter { $0.startTime >= weekAgo }
        let sequences = ContrastDetector.detectSequences(sessions: recentSessions)
        let fullContrast = sequences.filter { $0.isFullContrast }

        guard !fullContrast.isEmpty else { return [] }

        return [CoachingInsight(
            category: .contrast,
            title: "Contrast Therapy",
            body: "\(fullContrast.count) full contrast sequence\(fullContrast.count == 1 ? "" : "s") this week (sauna + cold). Contrast therapy enhances circulation and recovery beyond either modality alone.",
            icon: "arrow.triangle.2.circlepath",
            color: .purple,
            priority: 68
        )]
    }
}
