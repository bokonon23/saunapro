import Foundation
import SwiftData

@Model
final class SessionRecord {
    var id: UUID
    var sessionType: String
    var source: String
    var status: String

    // Timing
    var startTime: Date
    var endTime: Date
    var peakTime: Date?
    var durationMinutes: Double

    // Heart rate
    var baselineHR: Double?
    var peakHR: Double?
    var elevationAboveBaseline: Double?
    var recoveryMinutes: Double?

    // HRV
    var preSessionHRV: Double?
    var postSessionHRV: Double?
    var hrvDeltaPercent: Double?

    // Temperature
    var waterTemperature: Double?
    var wristTempBefore: Double?
    var wristTempAfter: Double?

    // Notes
    var notes: String?

    // Date key for grouping
    var dateKey: String

    init(
        id: UUID = UUID(),
        type: SessionType,
        source: SessionSource = .autoDetected,
        status: SessionStatus = .detected,
        startTime: Date,
        endTime: Date,
        peakTime: Date? = nil,
        baselineHR: Double? = nil,
        peakHR: Double? = nil,
        recoveryMinutes: Double? = nil,
        preSessionHRV: Double? = nil,
        postSessionHRV: Double? = nil,
        waterTemperature: Double? = nil,
        wristTempBefore: Double? = nil,
        wristTempAfter: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.sessionType = type.rawValue
        self.source = source.rawValue
        self.status = status.rawValue
        self.startTime = startTime
        self.endTime = endTime
        self.peakTime = peakTime
        self.durationMinutes = endTime.timeIntervalSince(startTime) / 60.0
        self.baselineHR = baselineHR
        self.peakHR = peakHR
        self.elevationAboveBaseline = if let peak = peakHR, let base = baselineHR { peak - base } else { nil }
        self.recoveryMinutes = recoveryMinutes
        self.preSessionHRV = preSessionHRV
        self.postSessionHRV = postSessionHRV
        self.hrvDeltaPercent = if let pre = preSessionHRV, let post = postSessionHRV, pre > 0 {
            ((post - pre) / pre) * 100.0
        } else {
            nil
        }
        self.waterTemperature = waterTemperature
        self.wristTempBefore = wristTempBefore
        self.wristTempAfter = wristTempAfter
        self.notes = notes

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateKey = formatter.string(from: startTime)
    }

    var type: SessionType {
        SessionType(rawValue: sessionType) ?? .sauna
    }

    var sessionSource: SessionSource {
        SessionSource(rawValue: source) ?? .autoDetected
    }

    var sessionStatus: SessionStatus {
        SessionStatus(rawValue: status) ?? .detected
    }
}
