import Foundation
import HealthKit

final class HealthKitManager: Sendable {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.heartRateRecoveryOneMinute),
            HKQuantityType(.bodyTemperature),
            HKQuantityType(.stepCount),
        ]
        if #available(iOS 16.0, *) {
            types.insert(HKQuantityType(.appleSleepingWristTemperature))
        }
        types.insert(HKQuantityType(.waterTemperature))
        types.insert(HKWorkoutType.workoutType())
        return types
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Queries

    func heartRateSamples(for date: Date) async throws -> [HealthSample] {
        try await querySamples(type: .heartRate, quantityType: HKQuantityType(.heartRate), unit: .count().unitDivided(by: .minute()), date: date)
    }

    func hrvSamples(for date: Date) async throws -> [HealthSample] {
        try await querySamples(type: .hrv, quantityType: HKQuantityType(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli), date: date)
    }

    func restingHeartRate(for date: Date) async throws -> Double? {
        let samples = try await querySamples(type: .restingHeartRate, quantityType: HKQuantityType(.restingHeartRate), unit: .count().unitDivided(by: .minute()), date: date)
        return samples.last?.value
    }

    func waterTemperatureSamples(for date: Date) async throws -> [HealthSample] {
        try await querySamples(type: .waterTemperature, quantityType: HKQuantityType(.waterTemperature), unit: .degreeCelsius(), date: date)
    }

    func wristTemperatureSamples(for date: Date) async throws -> [HealthSample] {
        if #available(iOS 16.0, *) {
            return try await querySamples(type: .wristTemperature, quantityType: HKQuantityType(.appleSleepingWristTemperature), unit: .degreeCelsius(), date: date)
        }
        return []
    }

    func heartRateRecoverySamples(for date: Date) async throws -> [HealthSample] {
        try await querySamples(type: .heartRateRecovery, quantityType: HKQuantityType(.heartRateRecoveryOneMinute), unit: .count().unitDivided(by: .minute()), date: date)
    }

    func stepCountSamples(for date: Date) async throws -> [HealthSample] {
        try await querySamples(type: .stepCount, quantityType: HKQuantityType(.stepCount), unit: .count(), date: date)
    }

    // MARK: - Full Day Query

    func fetchDayData(for date: Date) async throws -> DayData {
        async let hr = heartRateSamples(for: date)
        async let hrv = hrvSamples(for: date)
        async let rhr = restingHeartRate(for: date)
        async let waterTemp = waterTemperatureSamples(for: date)
        async let wristTemp = wristTemperatureSamples(for: date)
        async let steps = stepCountSamples(for: date)

        let allTemp = try await waterTemp + wristTemp

        return DayData(
            date: date,
            heartRateSamples: try await hr,
            hrvSamples: try await hrv,
            temperatureSamples: allTemp,
            stepSamples: try await steps,
            restingHeartRate: try await rhr
        )
    }

    // MARK: - Workouts

    struct WorkoutTimeRange: Sendable {
        let start: Date
        let end: Date
        let activityType: HKWorkoutActivityType
    }

    /// Returns time ranges of recorded workouts for the last N days.
    /// Used to filter out exercise (swimming, running, etc.) from sauna detection.
    func workoutTimeRanges(days: Int, from date: Date = Date()) async -> [WorkoutTimeRange] {
        guard isAvailable else { return [] }

        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = SortDescriptor(\HKWorkout.startDate, order: .forward)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [sortDescriptor]
        )

        do {
            let workouts = try await descriptor.result(for: store)
            return workouts.map { workout in
                WorkoutTimeRange(
                    start: workout.startDate,
                    end: workout.endDate,
                    activityType: workout.workoutActivityType
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Private

    private func querySamples(type: SampleType, quantityType: HKQuantityType, unit: HKUnit, date: Date) async throws -> [HealthSample] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .forward)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: quantityType, predicate: predicate)],
            sortDescriptors: [sortDescriptor]
        )

        let results = try await descriptor.result(for: store)

        return results.map { sample in
            HealthSample(
                type: type,
                value: sample.quantity.doubleValue(for: unit),
                timestamp: sample.startDate,
                source: sample.sourceRevision.source.name
            )
        }
    }
}
