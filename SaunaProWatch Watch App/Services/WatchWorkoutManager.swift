import Foundation
import HealthKit

@Observable
final class WatchWorkoutManager: NSObject {
    enum SessionState {
        case idle
        case running
        case coldPlunge
        case summary
    }

    // MARK: - Published State

    var state: SessionState = .idle
    var elapsedSeconds: Int = 0
    var currentHeartRate: Double = 0
    var peakHeartRate: Double = 0
    var averageHeartRate: Double = 0

    // Cold plunge
    var coldPlungeMarked = false
    var coldPlungeElapsedSeconds: Int = 0

    // Completed session
    var completedSession: WatchSessionData?

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var sessionStartDate: Date?
    private var sessionEndDate: Date?
    private var heartRateValues: [Double] = []
    private var timer: Timer?

    private var coldPlungeStartDate: Date?
    private var coldPlungeEndDate: Date?
    private var coldPlungeTimer: Timer?

    // MARK: - Authorization

    func requestAuthorization() async throws {
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate)
        ]
        let typesToWrite: Set<HKSampleType> = [
            HKWorkoutType.workoutType()
        ]
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }

    // MARK: - Sauna Session

    func startSaunaSession() async throws {
        try await requestAuthorization()

        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

        session.delegate = self
        builder.delegate = self

        workoutSession = session
        workoutBuilder = builder
        sessionStartDate = Date()
        heartRateValues = []
        peakHeartRate = 0
        averageHeartRate = 0
        currentHeartRate = 0
        elapsedSeconds = 0

        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        state = .running
        startTimer()
    }

    func stopSession() {
        sessionEndDate = Date()
        workoutSession?.end()

        timer?.invalidate()
        timer = nil

        buildCompletedSession()
        state = .summary
    }

    // MARK: - Cold Plunge

    func startColdPlunge() {
        coldPlungeMarked = true
        coldPlungeStartDate = Date()
        coldPlungeElapsedSeconds = 0
        state = .coldPlunge

        coldPlungeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.coldPlungeElapsedSeconds += 1
            }
        }
    }

    func stopColdPlunge() {
        coldPlungeEndDate = Date()
        coldPlungeTimer?.invalidate()
        coldPlungeTimer = nil

        buildCompletedSession()
        state = .summary
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        elapsedSeconds = 0
        currentHeartRate = 0
        peakHeartRate = 0
        averageHeartRate = 0
        coldPlungeMarked = false
        coldPlungeElapsedSeconds = 0
        completedSession = nil
        sessionStartDate = nil
        sessionEndDate = nil
        coldPlungeStartDate = nil
        coldPlungeEndDate = nil
        heartRateValues = []
        workoutSession = nil
        workoutBuilder = nil
    }

    // MARK: - Private Helpers

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func buildCompletedSession() {
        guard let start = sessionStartDate else { return }
        let end = sessionEndDate ?? Date()

        completedSession = WatchSessionData(
            sessionType: .sauna,
            startTime: start,
            endTime: end,
            peakHR: peakHeartRate > 0 ? peakHeartRate : nil,
            averageHR: averageHeartRate > 0 ? averageHeartRate : nil,
            coldPlungeMarked: coldPlungeMarked,
            coldPlungeStart: coldPlungeStartDate,
            coldPlungeEnd: coldPlungeEndDate ?? (coldPlungeMarked ? Date() : nil)
        )
    }

    private func updateHeartRate(_ bpm: Double) {
        currentHeartRate = bpm
        heartRateValues.append(bpm)

        if bpm > peakHeartRate {
            peakHeartRate = bpm
        }

        let sum = heartRateValues.reduce(0, +)
        averageHeartRate = sum / Double(heartRateValues.count)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                     didChangeTo toState: HKWorkoutSessionState,
                                     from fromState: HKWorkoutSessionState,
                                     date: Date) {
        Task { @MainActor in
            if toState == .ended {
                do {
                    try await self.workoutBuilder?.endCollection(at: date)
                    try await self.workoutBuilder?.finishWorkout()
                } catch {
                    // Workout save failed — session data is still available
                }
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                     didFailWithError error: Error) {
        // Handle workout session failure
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                     didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType) else { return }

        let statistics = workoutBuilder.statistics(for: hrType)
        guard let quantity = statistics?.mostRecentQuantity() else { return }

        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        Task { @MainActor in
            self.updateHeartRate(bpm)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Not used
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                     didBegin activity: HKWorkoutActivity) {
        // Not used
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                     didEnd activity: HKWorkoutActivity) {
        // Not used
    }
}
