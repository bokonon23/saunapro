import Foundation

struct EventDetector {

    struct Config {
        var elevationTarget: Double = 1.6       // HR must exceed baseline × this
        var peakThreshold: Double = 2.0          // Peak must reach baseline × this
        var minDurationMinutes: Double = 3       // Minimum session duration
        var maxGapMinutes: Double = 10           // Max gap between samples in same window
        var recoveryThreshold: Double = 10       // Recovery = HR drops to baseline + this
        var coldPlungeMaxMinutes: Double = 10    // Cold plunges are short
        var saunaMinMinutes: Double = 8          // Saunas last at least this long
    }

    let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    /// Detect sauna and cold plunge sessions from a day's health data.
    func detectSessions(dayData: DayData) -> [SessionRecord] {
        let hrSamples = dayData.heartRateSamples.sorted { $0.timestamp < $1.timestamp }
        guard !hrSamples.isEmpty else { return [] }

        let baselineHR = computeBaseline(samples: hrSamples, dayStart: dayData.date)
        guard baselineHR > 0 else { return [] }

        // Find elevated HR windows
        let windows = findElevatedWindows(samples: hrSamples, baselineHR: baselineHR)

        // Convert windows to session records
        var sessions: [SessionRecord] = []
        for window in windows {
            let duration = window.endTime.timeIntervalSince(window.startTime) / 60.0
            let sessionType = classifySession(window: window, baselineHR: baselineHR, waterTemps: dayData.temperatureSamples)
            let recoveryMinutes = computeRecoveryTime(samples: hrSamples, afterTime: window.endTime, baselineHR: baselineHR)
            let (preHRV, postHRV) = findHRVContext(hrvSamples: dayData.hrvSamples, sessionStart: window.startTime, sessionEnd: window.endTime)

            let session = SessionRecord(
                type: sessionType,
                startTime: window.startTime,
                endTime: window.endTime,
                peakTime: window.peakTime,
                baselineHR: baselineHR,
                peakHR: window.peakHR,
                recoveryMinutes: recoveryMinutes,
                preSessionHRV: preHRV,
                postSessionHRV: postHRV,
                waterTemperature: findNearestWaterTemp(temps: dayData.temperatureSamples, near: window.startTime)
            )
            sessions.append(session)
        }

        return sessions
    }

    // MARK: - Baseline

    /// Compute baseline HR from night readings (00:00–06:00), matching web app algorithm.
    private func computeBaseline(samples: [HealthSample], dayStart: Date) -> Double {
        let calendar = Calendar.current
        let nightStart = calendar.startOfDay(for: dayStart)
        guard let nightEnd = calendar.date(byAdding: .hour, value: 6, to: nightStart) else { return 0 }

        let nightSamples = samples.filter { $0.timestamp >= nightStart && $0.timestamp < nightEnd }
        guard !nightSamples.isEmpty else {
            // Fallback: use lowest 10th percentile of all samples
            let sorted = samples.sorted { $0.value < $1.value }
            let count = max(1, sorted.count / 10)
            let lowest = sorted.prefix(count)
            return lowest.map(\.value).reduce(0, +) / Double(lowest.count)
        }

        return nightSamples.map(\.value).reduce(0, +) / Double(nightSamples.count)
    }

    // MARK: - Window Detection

    struct DetectedWindow {
        let startTime: Date
        let endTime: Date
        let peakTime: Date
        let peakHR: Double
        let samples: [HealthSample]
    }

    private func findElevatedWindows(samples: [HealthSample], baselineHR: Double) -> [DetectedWindow] {
        let elevationThreshold = baselineHR * config.elevationTarget
        let peakRequired = baselineHR * config.peakThreshold
        let maxGap = config.maxGapMinutes * 60

        var windows: [DetectedWindow] = []
        var currentSamples: [HealthSample] = []

        for sample in samples {
            if sample.value >= elevationThreshold {
                if let last = currentSamples.last,
                   sample.timestamp.timeIntervalSince(last.timestamp) > maxGap {
                    // Gap too large — close current window
                    if let window = finalizeWindow(samples: currentSamples, peakRequired: peakRequired) {
                        windows.append(window)
                    }
                    currentSamples = []
                }
                currentSamples.append(sample)
            } else if !currentSamples.isEmpty {
                // HR dropped below threshold — close window
                if let window = finalizeWindow(samples: currentSamples, peakRequired: peakRequired) {
                    windows.append(window)
                }
                currentSamples = []
            }
        }

        // Close any remaining window
        if let window = finalizeWindow(samples: currentSamples, peakRequired: peakRequired) {
            windows.append(window)
        }

        return windows
    }

    private func finalizeWindow(samples: [HealthSample], peakRequired: Double) -> DetectedWindow? {
        guard !samples.isEmpty else { return nil }

        guard let peakSample = samples.max(by: { $0.value < $1.value }),
              peakSample.value >= peakRequired else { return nil }

        let duration = samples.last!.timestamp.timeIntervalSince(samples.first!.timestamp) / 60.0
        guard duration >= config.minDurationMinutes else { return nil }

        // Expand start backward to capture ramp-up (up to 10 min before first elevated sample)
        let expandedStart = samples.first!.timestamp.addingTimeInterval(-10 * 60)

        return DetectedWindow(
            startTime: max(expandedStart, samples.first!.timestamp),
            endTime: samples.last!.timestamp,
            peakTime: peakSample.timestamp,
            peakHR: peakSample.value,
            samples: samples
        )
    }

    // MARK: - Classification

    private func classifySession(window: DetectedWindow, baselineHR: Double, waterTemps: [HealthSample]) -> SessionType {
        let duration = window.endTime.timeIntervalSince(window.startTime) / 60.0

        // Check for nearby water temperature data (cold plunge indicator)
        let hasWaterTemp = findNearestWaterTemp(temps: waterTemps, near: window.startTime) != nil

        if duration <= config.coldPlungeMaxMinutes && hasWaterTemp {
            return .coldPlunge
        }

        // Short duration with HR spike pattern = cold plunge
        if duration <= config.coldPlungeMaxMinutes {
            let hrValues = window.samples.map(\.value)
            let earlyPeak = window.samples.prefix(max(1, window.samples.count / 3)).map(\.value).max() ?? 0
            let latePeak = window.samples.suffix(max(1, window.samples.count / 3)).map(\.value).max() ?? 0
            // Cold plunge: spike early, drop late
            if earlyPeak > latePeak * 1.2 {
                return .coldPlunge
            }
        }

        // Longer duration with sustained elevation = sauna
        if duration >= config.saunaMinMinutes {
            return .sauna
        }

        // Default based on duration
        return duration <= 5 ? .coldPlunge : .sauna
    }

    // MARK: - Recovery

    private func computeRecoveryTime(samples: [HealthSample], afterTime: Date, baselineHR: Double) -> Double? {
        let target = baselineHR + config.recoveryThreshold
        let postSamples = samples.filter { $0.timestamp > afterTime }.sorted { $0.timestamp < $1.timestamp }

        for sample in postSamples {
            if sample.value <= target {
                return sample.timestamp.timeIntervalSince(afterTime) / 60.0
            }
        }
        return nil
    }

    // MARK: - HRV Context

    private func findHRVContext(hrvSamples: [HealthSample], sessionStart: Date, sessionEnd: Date) -> (pre: Double?, post: Double?) {
        let preWindow: TimeInterval = 60 * 60 // 1 hour before
        let postWindow: TimeInterval = 60 * 60 // 1 hour after

        let preSamples = hrvSamples.filter {
            $0.timestamp >= sessionStart.addingTimeInterval(-preWindow) && $0.timestamp < sessionStart
        }
        let postSamples = hrvSamples.filter {
            $0.timestamp > sessionEnd && $0.timestamp <= sessionEnd.addingTimeInterval(postWindow)
        }

        // Take the closest sample to session boundaries
        let pre = preSamples.max(by: { $0.timestamp < $1.timestamp })?.value
        let post = postSamples.min(by: { $0.timestamp < $1.timestamp })?.value

        return (pre, post)
    }

    // MARK: - Temperature

    private func findNearestWaterTemp(temps: [HealthSample], near time: Date) -> Double? {
        let waterTemps = temps.filter { $0.type == .waterTemperature }
        let window: TimeInterval = 5 * 60 // 5 minutes

        return waterTemps
            .filter { abs($0.timestamp.timeIntervalSince(time)) <= window }
            .min(by: { abs($0.timestamp.timeIntervalSince(time)) < abs($1.timestamp.timeIntervalSince(time)) })?
            .value
    }
}
