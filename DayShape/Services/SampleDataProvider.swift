import Foundation

struct SampleDataProvider {

    /// Generates a realistic day of Apple Watch Ultra data with sauna and cold plunge sessions.
    /// Timeline:
    /// - 00:00–06:00: Night/sleep (low HR, wrist temp baseline)
    /// - 06:00–07:00: Morning routine (moderate HR)
    /// - 07:00–08:00: Light activity
    /// - 10:00–10:15: Sauna session (HR ramps to ~140)
    /// - 10:15–10:18: Cold plunge (HR spikes then drops, water temp ~5°C)
    /// - 10:18–10:45: Recovery period
    /// - 12:00–13:00: Midday
    /// - 16:00–16:15: Second sauna session
    /// - 16:15–16:18: Second cold plunge
    /// - 16:18–16:45: Recovery
    /// - 20:00–23:59: Evening wind-down
    static func generateDay(for date: Date) -> DayData {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let baselineHR: Double = 62

        var hrSamples: [HealthSample] = []
        var hrvSamples: [HealthSample] = []
        var tempSamples: [HealthSample] = []

        // --- Night (00:00–06:00): Low HR, stable wrist temp ---
        for minute in stride(from: 0, to: 360, by: 5) {
            let time = startOfDay.addingTimeInterval(Double(minute) * 60)
            let hr = baselineHR + Double.random(in: -4...4)
            hrSamples.append(HealthSample(type: .heartRate, value: hr, timestamp: time, source: "Apple Watch Ultra"))
        }
        // Overnight HRV readings
        for hour in [1, 3, 5] {
            let time = startOfDay.addingTimeInterval(Double(hour) * 3600)
            hrvSamples.append(HealthSample(type: .hrv, value: Double.random(in: 38...52), timestamp: time, source: "Apple Watch Ultra"))
        }
        // Wrist temperature baseline
        for hour in [2, 4] {
            let time = startOfDay.addingTimeInterval(Double(hour) * 3600)
            tempSamples.append(HealthSample(type: .wristTemperature, value: 36.5 + Double.random(in: -0.2...0.2), timestamp: time, source: "Apple Watch Ultra"))
        }

        // --- Morning (06:00–09:30): Gentle rise ---
        for minute in stride(from: 360, to: 570, by: 3) {
            let time = startOfDay.addingTimeInterval(Double(minute) * 60)
            let hr = baselineHR + 10 + Double.random(in: -5...8)
            hrSamples.append(HealthSample(type: .heartRate, value: hr, timestamp: time, source: "Apple Watch Ultra"))
        }
        // Pre-sauna HRV
        hrvSamples.append(HealthSample(type: .hrv, value: 45, timestamp: startOfDay.addingTimeInterval(9 * 3600 + 45 * 60), source: "Apple Watch Ultra"))

        // --- Sauna Session 1 (10:00–10:15) ---
        hrSamples.append(contentsOf: generateSaunaHR(baselineHR: baselineHR, sessionStart: startOfDay.addingTimeInterval(10 * 3600), durationMinutes: 15))

        // --- Cold Plunge 1 (10:17–10:20) ---
        let plunge1Start = startOfDay.addingTimeInterval(10 * 3600 + 17 * 60)
        hrSamples.append(contentsOf: generatePlungeHR(baselineHR: baselineHR, sessionStart: plunge1Start, durationMinutes: 3))
        // Water temperature (Ultra sensor)
        tempSamples.append(HealthSample(type: .waterTemperature, value: 5.2, timestamp: plunge1Start, source: "Apple Watch Ultra"))
        tempSamples.append(HealthSample(type: .waterTemperature, value: 5.4, timestamp: plunge1Start.addingTimeInterval(90), source: "Apple Watch Ultra"))
        tempSamples.append(HealthSample(type: .waterTemperature, value: 5.8, timestamp: plunge1Start.addingTimeInterval(170), source: "Apple Watch Ultra"))

        // --- Recovery 1 (10:20–10:50) ---
        hrSamples.append(contentsOf: generateRecoveryHR(baselineHR: baselineHR, peakHR: 85, recoveryStart: startOfDay.addingTimeInterval(10 * 3600 + 20 * 60), durationMinutes: 30))
        // Post-session HRV (suppressed)
        hrvSamples.append(HealthSample(type: .hrv, value: 28, timestamp: startOfDay.addingTimeInterval(10 * 3600 + 30 * 60), source: "Apple Watch Ultra"))
        // HRV rebound
        hrvSamples.append(HealthSample(type: .hrv, value: 55, timestamp: startOfDay.addingTimeInterval(11 * 3600), source: "Apple Watch Ultra"))

        // --- Midday (11:00–15:30) ---
        for minute in stride(from: 660, to: 930, by: 5) {
            let time = startOfDay.addingTimeInterval(Double(minute) * 60)
            let hr = baselineHR + 8 + Double.random(in: -5...10)
            hrSamples.append(HealthSample(type: .heartRate, value: hr, timestamp: time, source: "Apple Watch Ultra"))
        }

        // Pre-sauna 2 HRV
        hrvSamples.append(HealthSample(type: .hrv, value: 48, timestamp: startOfDay.addingTimeInterval(15 * 3600 + 45 * 60), source: "Apple Watch Ultra"))

        // --- Sauna Session 2 (16:00–16:15) ---
        hrSamples.append(contentsOf: generateSaunaHR(baselineHR: baselineHR, sessionStart: startOfDay.addingTimeInterval(16 * 3600), durationMinutes: 15))

        // --- Cold Plunge 2 (16:17–16:20) ---
        let plunge2Start = startOfDay.addingTimeInterval(16 * 3600 + 17 * 60)
        hrSamples.append(contentsOf: generatePlungeHR(baselineHR: baselineHR, sessionStart: plunge2Start, durationMinutes: 3))
        tempSamples.append(HealthSample(type: .waterTemperature, value: 4.8, timestamp: plunge2Start, source: "Apple Watch Ultra"))
        tempSamples.append(HealthSample(type: .waterTemperature, value: 5.1, timestamp: plunge2Start.addingTimeInterval(90), source: "Apple Watch Ultra"))
        tempSamples.append(HealthSample(type: .waterTemperature, value: 5.5, timestamp: plunge2Start.addingTimeInterval(170), source: "Apple Watch Ultra"))

        // --- Recovery 2 (16:20–16:50) ---
        hrSamples.append(contentsOf: generateRecoveryHR(baselineHR: baselineHR, peakHR: 82, recoveryStart: startOfDay.addingTimeInterval(16 * 3600 + 20 * 60), durationMinutes: 30))
        hrvSamples.append(HealthSample(type: .hrv, value: 25, timestamp: startOfDay.addingTimeInterval(16 * 3600 + 30 * 60), source: "Apple Watch Ultra"))
        hrvSamples.append(HealthSample(type: .hrv, value: 52, timestamp: startOfDay.addingTimeInterval(17 * 3600), source: "Apple Watch Ultra"))

        // --- Evening (17:00–23:59) ---
        for minute in stride(from: 1020, to: 1440, by: 5) {
            let time = startOfDay.addingTimeInterval(Double(minute) * 60)
            let hr = baselineHR + 5 + Double.random(in: -4...6)
            hrSamples.append(HealthSample(type: .heartRate, value: hr, timestamp: time, source: "Apple Watch Ultra"))
        }

        // Sort all samples by time
        hrSamples.sort { $0.timestamp < $1.timestamp }
        hrvSamples.sort { $0.timestamp < $1.timestamp }
        tempSamples.sort { $0.timestamp < $1.timestamp }

        return DayData(
            date: date,
            heartRateSamples: hrSamples,
            hrvSamples: hrvSamples,
            temperatureSamples: tempSamples,
            stepSamples: [],  // No steps during sauna in sample data
            restingHeartRate: baselineHR
        )
    }

    // MARK: - Session Generators

    /// Sauna: HR ramps from baseline+10 up to ~140 over the session duration
    private static func generateSaunaHR(baselineHR: Double, sessionStart: Date, durationMinutes: Int) -> [HealthSample] {
        var samples: [HealthSample] = []
        let peakHR = baselineHR * 2.2 // ~136 for baseline 62
        for minute in 0..<durationMinutes {
            let progress = Double(minute) / Double(durationMinutes)
            // Sigmoid-like ramp
            let targetHR = baselineHR + 10 + (peakHR - baselineHR - 10) * (progress * progress)
            let hr = targetHR + Double.random(in: -3...3)
            let time = sessionStart.addingTimeInterval(Double(minute) * 60)
            samples.append(HealthSample(type: .heartRate, value: hr, timestamp: time, source: "Apple Watch Ultra"))
        }
        return samples
    }

    /// Cold plunge: Initial HR spike (shock response), then rapid drop below baseline
    private static func generatePlungeHR(baselineHR: Double, sessionStart: Date, durationMinutes: Int) -> [HealthSample] {
        var samples: [HealthSample] = []
        let totalSeconds = durationMinutes * 60
        for second in stride(from: 0, to: totalSeconds, by: 15) {
            let progress = Double(second) / Double(totalSeconds)
            let hr: Double
            if progress < 0.15 {
                // Initial shock — HR spikes
                hr = baselineHR + 40 + Double.random(in: -5...5)
            } else if progress < 0.4 {
                // Settling
                hr = baselineHR + 20 - (progress * 30) + Double.random(in: -3...3)
            } else {
                // Parasympathetic takeover — HR drops below baseline
                hr = baselineHR - 5 + Double.random(in: -5...3)
            }
            let time = sessionStart.addingTimeInterval(Double(second))
            samples.append(HealthSample(type: .heartRate, value: max(hr, 45), timestamp: time, source: "Apple Watch Ultra"))
        }
        return samples
    }

    /// Recovery: HR gradually returns to baseline from a peak
    private static func generateRecoveryHR(baselineHR: Double, peakHR: Double, recoveryStart: Date, durationMinutes: Int) -> [HealthSample] {
        var samples: [HealthSample] = []
        for minute in 0..<durationMinutes {
            let progress = Double(minute) / Double(durationMinutes)
            // Exponential decay toward baseline
            let hr = baselineHR + (peakHR - baselineHR) * exp(-3.0 * progress) + Double.random(in: -3...3)
            let time = recoveryStart.addingTimeInterval(Double(minute) * 60)
            samples.append(HealthSample(type: .heartRate, value: hr, timestamp: time, source: "Apple Watch Ultra"))
        }
        return samples
    }
}
