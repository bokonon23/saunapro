import Foundation

struct EventDetector {

    struct Config {
        // HR thresholds
        var elevationTarget: Double = 1.5       // HR must exceed baseline × this to start a window
        var peakThreshold: Double = 1.8          // Peak must reach baseline × this
        var maxGapMinutes: Double = 10           // Max gap between samples in same window

        // Session merging — combine nearby windows into one sauna visit
        var mergeGapMinutes: Double = 25         // Merge windows within this gap (covers breaks between rounds)

        // Duration
        var saunaMinMinutes: Double = 10         // Saunas last at least 10 min
        var coldPlungeMaxMinutes: Double = 10    // Cold plunges are short

        // Recovery
        var recoveryThreshold: Double = 10       // Recovery = HR drops to baseline + this bpm

        // Step count filter
        var maxStepsPerMinute: Double = 5        // During sauna, you're stationary

        // Confidence scoring
        var minConfidence: Double = 0.5          // Reject sessions below this confidence

        // Habitual time windows (hour of day, 0-23)
        var habitualWindows: [(start: Int, end: Int)] = []  // e.g., [(11, 13)] for 11am-1pm
        var habitualBoost: Double = 0.15         // Confidence boost for matching habitual window
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

        // Find elevated HR windows and merge nearby ones (sauna rounds with breaks)
        let rawWindows = findElevatedWindows(samples: hrSamples, baselineHR: baselineHR)
        let windows = mergeNearbyWindows(rawWindows, allSamples: hrSamples)

        // Score and filter each window
        var sessions: [SessionRecord] = []
        for window in windows {
            let duration = window.endTime.timeIntervalSince(window.startTime) / 60.0

            // Calculate confidence score
            let confidence = scoreSession(
                window: window,
                baselineHR: baselineHR,
                duration: duration,
                stepSamples: dayData.stepSamples,
                temperatureSamples: dayData.temperatureSamples
            )

            // Reject low-confidence detections
            guard confidence >= config.minConfidence else { continue }

            let sessionType = classifySession(
                window: window,
                baselineHR: baselineHR,
                duration: duration,
                waterTemps: dayData.temperatureSamples
            )

            // Enforce minimum duration for sauna
            if sessionType == .sauna && duration < config.saunaMinMinutes {
                continue
            }

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

    // MARK: - Confidence Scoring

    /// Score a candidate session from 0.0 to 1.0 based on multiple signals.
    private func scoreSession(
        window: DetectedWindow,
        baselineHR: Double,
        duration: Double,
        stepSamples: [HealthSample],
        temperatureSamples: [HealthSample]
    ) -> Double {
        var score: Double = 0.0
        var maxScore: Double = 0.0

        // 1. Duration score (0-0.25) — longer sustained elevation = more likely sauna
        maxScore += 0.25
        if duration >= 15 {
            score += 0.25
        } else if duration >= 10 {
            score += 0.20
        } else if duration >= 5 {
            score += 0.10
        }

        // 2. HR elevation pattern (0-0.25) — sustained high HR, not spiky like exercise
        maxScore += 0.25
        let hrValues = window.samples.map(\.value)
        let avgElevation = hrValues.reduce(0, +) / Double(hrValues.count)
        let elevationRatio = avgElevation / baselineHR
        if elevationRatio >= 1.6 {
            score += 0.25
        } else if elevationRatio >= 1.4 {
            score += 0.15
        } else if elevationRatio >= 1.3 {
            score += 0.10
        }

        // 3. Step count score (0-0.25) — very low steps = stationary = sauna
        maxScore += 0.25
        let stepsInWindow = stepSamples.filter {
            $0.timestamp >= window.startTime && $0.timestamp <= window.endTime
        }
        let totalSteps = stepsInWindow.map(\.value).reduce(0, +)
        let stepsPerMinute = duration > 0 ? totalSteps / duration : 0

        if stepsPerMinute <= 1 {
            score += 0.25  // Essentially zero movement — very likely sauna
        } else if stepsPerMinute <= config.maxStepsPerMinute {
            score += 0.15  // Minimal movement
        } else if stepsPerMinute <= 15 {
            score += 0.05  // Some movement — could be light walking
        }
        // stepsPerMinute > 15 → likely exercise, no score added

        // 4. Temperature signal (0-0.10) — wrist temp rise during session
        maxScore += 0.10
        let wristTemps = temperatureSamples.filter { $0.type == .wristTemperature }
        let tempsNearSession = wristTemps.filter {
            abs($0.timestamp.timeIntervalSince(window.startTime)) < 60 * 60
        }
        if !tempsNearSession.isEmpty {
            score += 0.10  // Having wrist temp data near session time is a positive signal
        }

        // 5. Habitual time window bonus (0-0.15)
        maxScore += 0.15
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: window.startTime)
        let isHabitualTime = config.habitualWindows.contains { window in
            hour >= window.start && hour < window.end
        }
        if isHabitualTime {
            score += config.habitualBoost
        }

        return score / maxScore
    }

    // MARK: - Baseline

    /// Compute baseline HR from night readings (00:00–06:00).
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

    /// Merge windows that are close together into a single sauna visit.
    /// A typical sauna session has multiple rounds with short breaks (cool-down, shower, cold plunge).
    /// Without merging, each round appears as a separate session.
    private func mergeNearbyWindows(_ windows: [DetectedWindow], allSamples: [HealthSample]) -> [DetectedWindow] {
        guard windows.count > 1 else { return windows }

        let mergeGap = config.mergeGapMinutes * 60  // seconds

        var merged: [DetectedWindow] = []
        var current = windows[0]

        for i in 1..<windows.count {
            let next = windows[i]
            let gap = next.startTime.timeIntervalSince(current.endTime)

            if gap <= mergeGap {
                // Merge: combine into one window spanning both, including gap samples
                let combinedStart = current.startTime
                let combinedEnd = next.endTime

                // Gather all HR samples across the entire merged span
                let combinedSamples = allSamples.filter {
                    $0.timestamp >= combinedStart && $0.timestamp <= combinedEnd
                }

                let peakSample = combinedSamples.max(by: { $0.value < $1.value })

                current = DetectedWindow(
                    startTime: combinedStart,
                    endTime: combinedEnd,
                    peakTime: peakSample?.timestamp ?? current.peakTime,
                    peakHR: max(current.peakHR, next.peakHR),
                    samples: combinedSamples
                )
            } else {
                // Gap too large — keep current and start fresh
                merged.append(current)
                current = next
            }
        }
        merged.append(current)

        return merged
    }

    private func finalizeWindow(samples: [HealthSample], peakRequired: Double) -> DetectedWindow? {
        guard !samples.isEmpty else { return nil }

        guard let peakSample = samples.max(by: { $0.value < $1.value }),
              peakSample.value >= peakRequired else { return nil }

        let duration = samples.last!.timestamp.timeIntervalSince(samples.first!.timestamp) / 60.0
        guard duration >= 3 else { return nil }  // Absolute minimum — further filtering happens later

        return DetectedWindow(
            startTime: samples.first!.timestamp,
            endTime: samples.last!.timestamp,
            peakTime: peakSample.timestamp,
            peakHR: peakSample.value,
            samples: samples
        )
    }

    // MARK: - Classification

    private func classifySession(window: DetectedWindow, baselineHR: Double, duration: Double, waterTemps: [HealthSample]) -> SessionType {
        // Check for nearby water temperature data (cold plunge indicator)
        let hasWaterTemp = findNearestWaterTemp(temps: waterTemps, near: window.startTime) != nil

        if duration <= config.coldPlungeMaxMinutes && hasWaterTemp {
            return .coldPlunge
        }

        // Short duration with early HR spike pattern = cold plunge
        if duration <= config.coldPlungeMaxMinutes {
            let earlyPeak = window.samples.prefix(max(1, window.samples.count / 3)).map(\.value).max() ?? 0
            let latePeak = window.samples.suffix(max(1, window.samples.count / 3)).map(\.value).max() ?? 0
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
        let preWindow: TimeInterval = 60 * 60
        let postWindow: TimeInterval = 60 * 60

        let preSamples = hrvSamples.filter {
            $0.timestamp >= sessionStart.addingTimeInterval(-preWindow) && $0.timestamp < sessionStart
        }
        let postSamples = hrvSamples.filter {
            $0.timestamp > sessionEnd && $0.timestamp <= sessionEnd.addingTimeInterval(postWindow)
        }

        let pre = preSamples.max(by: { $0.timestamp < $1.timestamp })?.value
        let post = postSamples.min(by: { $0.timestamp < $1.timestamp })?.value

        return (pre, post)
    }

    // MARK: - Temperature

    private func findNearestWaterTemp(temps: [HealthSample], near time: Date) -> Double? {
        let waterTemps = temps.filter { $0.type == .waterTemperature }
        let window: TimeInterval = 5 * 60

        return waterTemps
            .filter { abs($0.timestamp.timeIntervalSince(time)) <= window }
            .min(by: { abs($0.timestamp.timeIntervalSince(time)) < abs($1.timestamp.timeIntervalSince(time)) })?
            .value
    }
}
