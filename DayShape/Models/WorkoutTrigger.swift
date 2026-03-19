import Foundation
import HealthKit

/// Maps HKWorkoutActivityType values to user-friendly display names for the workout trigger settings.
/// Users pick which workout types their watch uses to log sauna/cold sessions.
enum WorkoutTrigger: CaseIterable, Identifiable {
    case other          // Apple Watch default recommendation
    case yoga           // Good Garmin option for sauna
    case mindAndBody    // Alternative for Garmin/Fitbit
    case flexibility    // Another calm-activity option
    case cooldown       // Could map well to cold exposure
    case swimBikeRun    // Some users use swim for cold plunge

    var id: UInt { activityType.rawValue }

    var activityType: HKWorkoutActivityType {
        switch self {
        case .other: .other
        case .yoga: .yoga
        case .mindAndBody: .mindAndBody
        case .flexibility: .flexibility
        case .cooldown: .cooldown
        case .swimBikeRun: .swimming
        }
    }

    var label: String {
        switch self {
        case .other: "Other"
        case .yoga: "Yoga"
        case .mindAndBody: "Mind & Body"
        case .flexibility: "Flexibility"
        case .cooldown: "Cooldown"
        case .swimBikeRun: "Swimming"
        }
    }

    var subtitle: String {
        switch self {
        case .other: "Apple Watch — recommended"
        case .yoga: "Garmin, Fitbit — recommended"
        case .mindAndBody: "Garmin, Samsung, Fitbit"
        case .flexibility: "Garmin, Samsung"
        case .cooldown: "Good for cold exposure sessions"
        case .swimBikeRun: "Open water / cold plunge"
        }
    }

    var icon: String {
        switch self {
        case .other: "ellipsis.circle"
        case .yoga: "figure.yoga"
        case .mindAndBody: "brain.head.profile"
        case .flexibility: "figure.flexibility"
        case .cooldown: "wind"
        case .swimBikeRun: "figure.pool.swim"
        }
    }

    /// The default session type for workouts of this trigger type.
    /// Swimming defaults to cold plunge; others use duration-based detection.
    var defaultSessionType: String? {
        switch self {
        case .swimBikeRun: "swimming"
        case .cooldown: "coldPlunge"
        default: nil  // Use normal duration-based classification
        }
    }

    /// Look up the default session type for a given workout activity type.
    static func defaultSessionType(for type: HKWorkoutActivityType) -> String? {
        allCases.first { $0.activityType == type }?.defaultSessionType
    }

    /// Look up the display name for any HKWorkoutActivityType.
    static func displayName(for type: HKWorkoutActivityType) -> String {
        allCases.first { $0.activityType == type }?.label ?? "Workout"
    }

    // MARK: - UserDefaults persistence

    static let defaultTriggers: Set<UInt> = [HKWorkoutActivityType.other.rawValue]

    static func savedTriggers() -> Set<UInt> {
        guard let stored = UserDefaults.standard.array(forKey: "triggerWorkoutTypes") as? [UInt] else {
            return defaultTriggers
        }
        return Set(stored)
    }

    static func saveTriggers(_ triggers: Set<UInt>) {
        UserDefaults.standard.set(Array(triggers), forKey: "triggerWorkoutTypes")
    }
}
