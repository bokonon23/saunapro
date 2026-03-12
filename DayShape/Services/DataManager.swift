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
    private let detector = EventDetector()

    func loadToday() async {
        await loadDay(Date())
    }

    func loadDay(_ date: Date) async {
        isLoading = true
        errorMessage = nil

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

            // Filter out sessions that overlap with recorded workouts
            if healthKit.isAvailable {
                let workoutTimes = await healthKit.workoutTimeRanges(days: 1, from: date)
                detected = detected.filter { session in
                    !workoutTimes.contains { workout in
                        session.startTime < workout.end && session.endTime > workout.start
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

    /// Scan the last N days for sessions and save them to SwiftData.
    func scanHistory(days: Int = 30, modelContext: ModelContext) async {
        guard healthKit.isAvailable else { return }

        do {
            try await healthKit.requestAuthorization()
        } catch {
            return
        }

        // Get workout times so we can exclude exercise sessions
        let workoutTimes = await healthKit.workoutTimeRanges(days: days)

        let calendar = Calendar.current
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateKey = dateFormatter.string(from: date)

            historyScanProgress = "Scanning \(dateFormatter.string(from: date))..."

            // Skip if we already have sessions for this day
            let descriptor = FetchDescriptor<SessionRecord>(
                predicate: #Predicate { $0.dateKey == dateKey }
            )
            let existing = (try? modelContext.fetch(descriptor)) ?? []
            if !existing.isEmpty { continue }

            // Load day data and detect sessions
            do {
                let data = try await healthKit.fetchDayData(for: date)
                guard !data.heartRateSamples.isEmpty else { continue }

                let detected = detector.detectSessions(dayData: data)
                for session in detected {
                    // Skip sessions that overlap with workouts (e.g. swimming)
                    let overlapsWorkout = workoutTimes.contains { workout in
                        session.startTime < workout.end && session.endTime > workout.start
                    }
                    if overlapsWorkout { continue }

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
