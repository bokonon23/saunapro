import Foundation
import HealthKit
import SwiftData
import Observation

@Observable
final class DataManager {
    var dayData: DayData?
    var sessions: [SessionRecord] = []
    var isLoading = false
    var errorMessage: String?
    var isUsingSimulatorData = false
    var historyScanProgress: String?

    private let healthKit = HealthKitManager.shared

    /// Returns the HKWorkoutActivityTypes the user has configured as sauna triggers.
    /// Default: [.other]. Users with Garmin etc. can add .yoga and others.
    private var triggerWorkoutTypes: [HKWorkoutActivityType] {
        let stored = UserDefaults.standard.array(forKey: "triggerWorkoutTypes") as? [UInt] ?? [HKWorkoutActivityType.other.rawValue]
        return stored.compactMap { HKWorkoutActivityType(rawValue: $0) }
    }

    /// Activity types that should NOT be filtered as exercise when they're selected as triggers.
    private var triggerRawValues: Set<UInt> {
        Set(triggerWorkoutTypes.map { $0.rawValue })
    }

    /// Build detector config from user settings (AppStorage values).
    private func makeDetector() -> EventDetector {
        let sensitivity = UserDefaults.standard.double(forKey: "detectionSensitivity")
        let minMinutes = UserDefaults.standard.double(forKey: "saunaMinMinutes")
        let startHour = UserDefaults.standard.integer(forKey: "habitualStartHour")
        let endHour = UserDefaults.standard.integer(forKey: "habitualEndHour")

        var config = EventDetector.Config()
        if sensitivity > 0 {
            config.elevationTarget = sensitivity
            config.peakThreshold = sensitivity + 0.3
        }
        if minMinutes > 0 {
            config.saunaMinMinutes = minMinutes
        }
        if startHour > 0 && endHour > startHour {
            config.habitualWindows = [(start: startHour, end: endHour)]
        }

        return EventDetector(config: config)
    }

    func loadToday() async {
        await loadDay(Date())
    }

    func loadDay(_ date: Date) async {
        isLoading = true
        errorMessage = nil

        let detector = makeDetector()

        do {
            let data: DayData

            if healthKit.isAvailable {
                try await healthKit.requestAuthorization()
                data = try await healthKit.fetchDayData(for: date)
                isUsingSimulatorData = false

                // If HealthKit returns no HR data, fall back to sample data
                if data.heartRateSamples.isEmpty {
                    let sampleData = SampleDataProvider.generateDay(for: date)
                    self.dayData = sampleData
                    isUsingSimulatorData = true
                    sessions = detector.detectSessions(dayData: sampleData)
                    isLoading = false
                    return
                }
            } else {
                // Simulator — use sample data
                data = SampleDataProvider.generateDay(for: date)
                isUsingSimulatorData = true
            }

            self.dayData = data
            var detected = detector.detectSessions(dayData: data)

            // Separate exercise workouts from trigger workouts (sauna sessions)
            if healthKit.isAvailable {
                let triggers = triggerRawValues
                let workoutTimes = await healthKit.workoutTimeRanges(days: 1, from: date)
                let exerciseWorkouts = workoutTimes.filter { !triggers.contains($0.activityType.rawValue) }

                // Filter out auto-detected HR spikes that overlap with exercise workouts
                detected = detected.filter { session in
                    !exerciseWorkouts.contains { workout in
                        session.startTime < workout.end && session.endTime > workout.start
                    }
                }

                // Create informational exercise sessions so the day view isn't empty
                for workout in exerciseWorkouts {
                    let durationMinutes = workout.end.timeIntervalSince(workout.start) / 60.0
                    guard durationMinutes >= 3 else { continue }

                    let session = SessionRecord(
                        type: .exercise,
                        source: .autoDetected,
                        status: .confirmed,
                        startTime: workout.start,
                        endTime: workout.end,
                        peakHR: workout.peakHeartRate,
                        notes: "\(workout.activityType.displayName) via \(workout.sourceName)"
                    )
                    session.baselineHR = data.restingHeartRate
                    if let avg = workout.averageHeartRate {
                        // Store average HR in a note since we don't have a dedicated field
                        let energyStr = workout.totalEnergy.map { String(format: " • %.0f kcal", $0) } ?? ""
                        session.notes = "\(workout.activityType.displayName) via \(workout.sourceName) • Avg HR \(Int(avg)) bpm\(energyStr)"
                    }
                    detected.append(session)
                }

                // Convert trigger workouts into confirmed sauna sessions
                let matchedWorkouts = await healthKit.triggerWorkouts(for: date, activityTypes: triggerWorkoutTypes)
                for workout in matchedWorkouts {
                    let durationMinutes = workout.duration / 60.0

                    // Skip very short workouts (< 3 min) — likely accidental
                    guard durationMinutes >= 3 else { continue }

                    // Check if we already have a detected session overlapping this workout
                    let overlapIndex = detected.firstIndex { session in
                        session.startTime < workout.end && session.endTime > workout.start
                    }

                    let workoutLabel = WorkoutTrigger.displayName(for: workout.activityType)
                    let sourceNote = "Recorded via \(workout.sourceName) (\(workoutLabel))"

                    if let idx = overlapIndex {
                        // Upgrade existing detected session — confirm it and use workout timing
                        detected[idx].status = SessionStatus.confirmed.rawValue
                        detected[idx].source = SessionSource.manual.rawValue
                        detected[idx].startTime = workout.start
                        detected[idx].endTime = workout.end
                        detected[idx].durationMinutes = durationMinutes
                        detected[idx].notes = sourceNote
                        if let peakHR = workout.maxHeartRate {
                            detected[idx].peakHR = peakHR
                        }
                    } else {
                        // Create new confirmed sauna session from trigger workout
                        let session = SessionRecord(
                            type: durationMinutes <= 5 ? .coldPlunge : .sauna,
                            source: .manual,
                            status: .confirmed,
                            startTime: workout.start,
                            endTime: workout.end,
                            peakHR: workout.maxHeartRate,
                            notes: sourceNote
                        )
                        session.baselineHR = data.restingHeartRate
                        detected.append(session)
                    }
                }
            }

            sessions = detected
        } catch {
            // Fall back to sample data on any error
            let sampleData = SampleDataProvider.generateDay(for: date)
            self.dayData = sampleData
            isUsingSimulatorData = true
            sessions = detector.detectSessions(dayData: sampleData)
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Import a session received from Apple Watch via WatchConnectivity.
    func importWatchSession(_ watchData: WatchSessionData, modelContext: ModelContext? = nil) {
        guard let context = modelContext else { return }

        let type = SessionType(rawValue: watchData.sessionType) ?? .sauna

        let session = SessionRecord(
            id: watchData.id,
            type: type,
            source: .watchApp,
            status: .confirmed,
            startTime: watchData.startTime,
            endTime: watchData.endTime,
            peakHR: watchData.peakHR
        )
        session.notes = "Recorded on Apple Watch"

        // Contrast therapy: create one SessionRecord per round with shared groupId
        if let rounds = watchData.contrastRounds, !rounds.isEmpty {
            let groupId = watchData.contrastGroupId ?? UUID()
            session.contrastGroupId = groupId
            context.insert(session)

            for round in rounds {
                let roundType: SessionType = round.phase == "coldPlunge" ? .coldPlunge : .sauna
                let roundSession = SessionRecord(
                    type: roundType,
                    source: .watchApp,
                    status: .confirmed,
                    startTime: round.startTime,
                    endTime: round.endTime,
                    peakHR: round.peakHR
                )
                roundSession.contrastGroupId = groupId
                roundSession.notes = "Contrast R\(round.roundNumber) — \(round.phase) (Apple Watch)"
                context.insert(roundSession)
            }
        } else {
            context.insert(session)

            // If cold plunge was marked, create a separate session
            if watchData.coldPlungeMarked,
               let cpStart = watchData.coldPlungeStart,
               let cpEnd = watchData.coldPlungeEnd {
                let cpSession = SessionRecord(
                    type: .coldPlunge,
                    source: .watchApp,
                    status: .confirmed,
                    startTime: cpStart,
                    endTime: cpEnd
                )
                cpSession.notes = "Cold plunge recorded on Apple Watch"
                context.insert(cpSession)
            }
        }

        try? context.save()
    }

    /// Scan the last N days for sessions and save them to SwiftData.
    func scanHistory(days: Int = 30, modelContext: ModelContext) async {
        guard healthKit.isAvailable else { return }

        do {
            try await healthKit.requestAuthorization()
        } catch {
            return
        }

        let detector = makeDetector()

        // Get workout times so we can exclude exercise sessions (but NOT trigger workouts)
        let triggers = triggerRawValues
        let workoutTimes = await healthKit.workoutTimeRanges(days: days)
        let exerciseWorkouts = workoutTimes.filter { !triggers.contains($0.activityType.rawValue) }

        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateKey = dateFormatter.string(from: date)

            historyScanProgress = "Scanning \(dateKey)..."

            // Skip if we already have sessions for this day
            let descriptor = FetchDescriptor<SessionRecord>(
                predicate: #Predicate { $0.dateKey == dateKey }
            )
            let existing = (try? modelContext.fetch(descriptor)) ?? []
            if !existing.isEmpty { continue }

            // Load day data and detect sessions
            do {
                let data = try await healthKit.fetchDayData(for: date)

                // First: import trigger workouts (Other, Yoga, etc.) as confirmed sessions
                let matchedWorkouts = await healthKit.triggerWorkouts(for: date, activityTypes: triggerWorkoutTypes)
                for workout in matchedWorkouts {
                    let durationMinutes = workout.duration / 60.0
                    guard durationMinutes >= 3 else { continue }

                    let workoutLabel = WorkoutTrigger.displayName(for: workout.activityType)
                    let session = SessionRecord(
                        type: durationMinutes <= 5 ? .coldPlunge : .sauna,
                        source: .manual,
                        status: .confirmed,
                        startTime: workout.start,
                        endTime: workout.end,
                        peakHR: workout.maxHeartRate,
                        notes: "Recorded via \(workout.sourceName) (\(workoutLabel))"
                    )
                    session.baselineHR = data.restingHeartRate
                    modelContext.insert(session)
                }

                // Then: auto-detect additional sessions from HR data
                guard !data.heartRateSamples.isEmpty else {
                    try? modelContext.save()
                    continue
                }

                let detected = detector.detectSessions(dayData: data)
                for session in detected {
                    // Skip sessions that overlap with exercise workouts
                    let overlapsExercise = exerciseWorkouts.contains { workout in
                        session.startTime < workout.end && session.endTime > workout.start
                    }
                    if overlapsExercise { continue }

                    // Skip sessions that overlap with already-imported trigger workouts
                    let overlapsTrigger = matchedWorkouts.contains { workout in
                        session.startTime < workout.end && session.endTime > workout.start
                    }
                    if overlapsTrigger { continue }

                    modelContext.insert(session)
                }
                try? modelContext.save()
            } catch {
                continue
            }
        }
        historyScanProgress = nil
    }
}
