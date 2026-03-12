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
            sessions = detector.detectSessions(dayData: data)
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
}
