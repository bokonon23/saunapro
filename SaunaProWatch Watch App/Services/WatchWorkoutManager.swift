import Foundation
import HealthKit

@Observable
final class WatchWorkoutManager: NSObject {
    enum SessionState {
        case idle
        case starting      // Brief loading state while HealthKit initializes
        case running
        case coldPlunge
        case summary

        // Contrast therapy flow
        case contrastSauna
        case contrastCold
        case contrastTransition
        case contrastSummary
    }

    // MARK: - Published State

    var state: SessionState = .idle
    var isAuthorized = false
    var elapsedSeconds: Int = 0
    var currentHeartRate: Double = 0
    var peakHeartRate: Double = 0
    var averageHeartRate: Double = 0

    // Cold plunge (existing flow)
    var coldPlungeMarked = false
    var coldPlungeElapsedSeconds: Int = 0

    // Completed session
    var completedSession: WatchSessionData?

    // MARK: - Contrast Mode

    var isContrastMode = false
    var contrastRoundNumber: Int = 0
    var contrastRounds: [ContrastRound] = []
    var contrastGroupId: UUID?
    var contrastPhaseElapsedSeconds: Int = 0
    var contrastNextPhase: String = ""

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

    // Contrast phase tracking
    private var phaseStartDate: Date?
    private var phaseHeartRateValues: [Double] = []
    private var phasePeakHR: Double = 0
    private var phaseTimer: Timer?

    // MARK: - Authorization

    func requestAuthorization() async {
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate)
        ]
        let typesToWrite: Set<HKSampleType> = [
            HKWorkoutType.workoutType()
        ]
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            isAuthorized = true
        } catch {
            // Authorization failed — buttons will still show, session start will retry
            isAuthorized = true  // Let them try anyway; HK will prompt if needed
        }
    }

    // MARK: - Shared Workout Setup

    private func startWorkoutSession() async throws {
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

        startTimer()
    }

    // MARK: - Sauna Session (existing flow)

    func startSaunaSession() async throws {
        state = .starting
        try await startWorkoutSession()
        state = .running
    }

    func stopSession() {
        sessionEndDate = Date()
        workoutSession?.end()

        timer?.invalidate()
        timer = nil

        buildCompletedSession()
        state = .summary
    }

    // MARK: - Cold Plunge (existing flow)

    func startColdPlunge() {
        coldPlungeMarked = true
        coldPlungeStartDate = Date()
        coldPlungeElapsedSeconds = 0
        state = .coldPlunge

        coldPlungeTimer?.invalidate()
        coldPlungeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.coldPlungeStartDate else { return }
                self.coldPlungeElapsedSeconds = Int(Date().timeIntervalSince(start))
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

    // MARK: - Contrast Therapy

    func startContrastSession() async throws {
        state = .starting
        try await startWorkoutSession()

        isContrastMode = true
        contrastGroupId = UUID()
        contrastRoundNumber = 1
        contrastRounds = []

        beginContrastSaunaPhase()
    }

    func beginContrastSaunaPhase() {
        phaseStartDate = Date()
        phaseHeartRateValues = []
        phasePeakHR = 0
        contrastPhaseElapsedSeconds = 0
        state = .contrastSauna

        startPhaseTimer()
    }

    func endContrastSaunaPhase(switchToCold: Bool) {
        saveCurrentPhaseRound(phase: "sauna")
        stopPhaseTimer()

        if switchToCold {
            contrastNextPhase = "cold"
            state = .contrastTransition
        } else {
            finishContrastSession(endedOnCold: false)
        }
    }

    func beginContrastColdPhase() {
        phaseStartDate = Date()
        phaseHeartRateValues = []
        phasePeakHR = 0
        contrastPhaseElapsedSeconds = 0
        state = .contrastCold

        startPhaseTimer()
    }

    func endContrastColdPhase(switchToSauna: Bool) {
        saveCurrentPhaseRound(phase: "coldPlunge")
        stopPhaseTimer()

        if switchToSauna {
            contrastRoundNumber += 1
            contrastNextPhase = "sauna"
            state = .contrastTransition
        } else {
            finishContrastSession(endedOnCold: true)
        }
    }

    func contrastTransitionComplete() {
        if contrastNextPhase == "cold" {
            beginContrastColdPhase()
        } else {
            beginContrastSaunaPhase()
        }
    }

    private func finishContrastSession(endedOnCold: Bool) {
        sessionEndDate = Date()
        workoutSession?.end()

        timer?.invalidate()
        timer = nil

        guard let start = sessionStartDate else { return }
        let end = sessionEndDate ?? Date()

        completedSession = WatchSessionData(
            sessionType: .sauna,
            startTime: start,
            endTime: end,
            peakHR: peakHeartRate > 0 ? peakHeartRate : nil,
            averageHR: averageHeartRate > 0 ? averageHeartRate : nil,
            contrastRounds: contrastRounds,
            contrastGroupId: contrastGroupId,
            endedOnCold: endedOnCold
        )

        state = .contrastSummary
    }

    private func saveCurrentPhaseRound(phase: String) {
        guard let start = phaseStartDate else { return }
        let end = Date()
        let avgHR: Double? = phaseHeartRateValues.isEmpty ? nil :
            phaseHeartRateValues.reduce(0, +) / Double(phaseHeartRateValues.count)

        let round = ContrastRound(
            roundNumber: contrastRoundNumber,
            phase: phase,
            startTime: start,
            endTime: end,
            durationSeconds: contrastPhaseElapsedSeconds,
            peakHR: phasePeakHR > 0 ? phasePeakHR : nil,
            averageHR: avgHR
        )
        contrastRounds.append(round)
    }

    private func startPhaseTimer() {
        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.phaseStartDate else { return }
                self.contrastPhaseElapsedSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }

    private func stopPhaseTimer() {
        phaseTimer?.invalidate()
        phaseTimer = nil
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

        // Contrast state
        isContrastMode = false
        contrastRoundNumber = 0
        contrastRounds = []
        contrastGroupId = nil
        contrastPhaseElapsedSeconds = 0
        contrastNextPhase = ""
        phaseStartDate = nil
        phaseHeartRateValues = []
        phasePeakHR = 0
        phaseTimer?.invalidate()
        phaseTimer = nil
    }

    // MARK: - Private Helpers

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.sessionStartDate else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
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

        // Track per-phase HR in contrast mode
        if isContrastMode {
            phaseHeartRateValues.append(bpm)
            if bpm > phasePeakHR {
                phasePeakHR = bpm
            }
        }
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
