import Foundation

struct ContrastRound: Codable {
    let roundNumber: Int
    let phase: String
    let startTime: Date
    let endTime: Date
    let durationSeconds: Int
    let peakHR: Double?
    let averageHR: Double?
}

struct WatchSessionData: Codable, Identifiable {
    let id: UUID
    let sessionType: String
    let startTime: Date
    let endTime: Date
    let durationMinutes: Double
    let peakHR: Double?
    let averageHR: Double?
    let coldPlungeMarked: Bool
    let coldPlungeStart: Date?
    let coldPlungeEnd: Date?

    // Contrast therapy (optional, nil for legacy sessions)
    let contrastRounds: [ContrastRound]?
    let contrastGroupId: UUID?
    let endedOnCold: Bool?

    init(
        id: UUID = UUID(),
        sessionType: SessionType = .sauna,
        startTime: Date,
        endTime: Date,
        peakHR: Double? = nil,
        averageHR: Double? = nil,
        coldPlungeMarked: Bool = false,
        coldPlungeStart: Date? = nil,
        coldPlungeEnd: Date? = nil,
        contrastRounds: [ContrastRound]? = nil,
        contrastGroupId: UUID? = nil,
        endedOnCold: Bool? = nil
    ) {
        self.id = id
        self.sessionType = sessionType.rawValue
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = endTime.timeIntervalSince(startTime) / 60.0
        self.peakHR = peakHR
        self.averageHR = averageHR
        self.coldPlungeMarked = coldPlungeMarked
        self.coldPlungeStart = coldPlungeStart
        self.coldPlungeEnd = coldPlungeEnd
        self.contrastRounds = contrastRounds
        self.contrastGroupId = contrastGroupId
        self.endedOnCold = endedOnCold
    }
}
