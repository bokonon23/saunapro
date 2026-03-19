import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(
        filter: #Predicate<SessionRecord> { $0.status != "dismissed" },
        sort: \SessionRecord.startTime,
        order: .reverse
    ) private var recentSessions: [SessionRecord]

    @State private var aiCoachingText: String?
    @State private var isLoadingAI = false
    @State private var showAICoaching = false

    var body: some View {
        let insights = CoachingEngine.generateInsights(from: recentSessions)

        if !insights.isEmpty || showAICoaching {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    Text("Coaching Insights")
                        .font(.headline)
                }
                .padding(.horizontal)

                ForEach(insights.prefix(4)) { insight in
                    InsightCardView(insight: insight)
                        .padding(.horizontal)
                }

                // AI coaching section
                aiCoachingSection
                    .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var aiCoachingSection: some View {
        if let text = aiCoachingText {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("AI Coach")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                }
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if FoundationModelProvider.isAvailable {
            Button {
                Task { await loadAICoaching() }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(isLoadingAI ? "Generating..." : "Get AI Coaching")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(isLoadingAI)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Coach")
                        .font(.subheadline.bold())
                    Text("Available on devices with Apple Intelligence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func loadAICoaching() async {
        isLoadingAI = true
        defer { isLoadingAI = false }

        let summary = FoundationModelProvider.buildSessionSummary(from: Array(recentSessions.prefix(30)))
        let provider = FoundationModelProvider()
        do {
            aiCoachingText = try await provider.generateCoaching(sessionSummary: summary)
        } catch {
            aiCoachingText = "Unable to generate coaching insights right now. Try again later."
        }
    }
}

struct InsightCardView: View {
    let insight: CoachingInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(insight.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.bold())
                Text(insight.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
