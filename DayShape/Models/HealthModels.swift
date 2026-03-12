import Foundation

enum SampleType: String, Codable {
    case heartRate
    case restingHeartRate
    case hrv
    case heartRateRecovery
    case wristTemperature
    case waterTemperature
    case stepCount
}

struct HealthSample: Identifiable, Codable {
    let id: UUID
    let type: SampleType
    let value: Double
    let timestamp: Date
    let source: String?

    init(id: UUID = UUID(), type: SampleType, value: Double, timestamp: Date, source: String? = nil) {
        self.id = id
        self.type = type
        self.value = value
        self.timestamp = timestamp
        self.source = source
    }
}

struct DayData: Identifiable {
    let id: UUID
    let date: Date
    var heartRateSamples: [HealthSample]
    var hrvSamples: [HealthSample]
    var temperatureSamples: [HealthSample]
    var stepSamples: [HealthSample]
    var restingHeartRate: Double?
    var sessions: [SessionRecord]

    init(id: UUID = UUID(), date: Date, heartRateSamples: [HealthSample] = [], hrvSamples: [HealthSample] = [], temperatureSamples: [HealthSample] = [], stepSamples: [HealthSample] = [], restingHeartRate: Double? = nil, sessions: [SessionRecord] = []) {
        self.id = id
        self.date = date
        self.heartRateSamples = heartRateSamples
        self.hrvSamples = hrvSamples
        self.temperatureSamples = temperatureSamples
        self.stepSamples = stepSamples
        self.restingHeartRate = restingHeartRate
        self.sessions = sessions
    }
}
