import Foundation

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

    init(
        id: UUID = UUID(),
        sessionType: SessionType = .sauna,
        startTime: Date,
        endTime: Date,
        peakHR: Double? = nil,
        averageHR: Double? = nil,
        coldPlungeMarked: Bool = false,
        coldPlungeStart: Date? = nil,
        coldPlungeEnd: Date? = nil
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
    }
}
