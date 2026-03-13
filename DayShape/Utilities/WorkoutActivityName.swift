import HealthKit

extension HKWorkoutActivityType {
    /// Human-readable name for common workout activity types.
    var displayName: String {
        switch self {
        case .running: "Running"
        case .cycling: "Cycling"
        case .walking: "Walking"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .functionalStrengthTraining: "Strength Training"
        case .traditionalStrengthTraining: "Weight Training"
        case .coreTraining: "Core Training"
        case .highIntensityIntervalTraining: "HIIT"
        case .crossTraining: "Cross Training"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .stairClimbing: "Stair Climbing"
        case .pilates: "Pilates"
        case .dance: "Dance"
        case .cooldown: "Cooldown"
        case .mindAndBody: "Mind & Body"
        case .flexibility: "Flexibility"
        case .mixedCardio: "Mixed Cardio"
        case .jumpRope: "Jump Rope"
        case .kickboxing: "Kickboxing"
        case .boxing: "Boxing"
        case .tennis: "Tennis"
        case .badminton: "Badminton"
        case .tableTennis: "Table Tennis"
        case .soccer: "Football"
        case .basketball: "Basketball"
        case .golf: "Golf"
        case .rugby: "Rugby"
        case .cricket: "Cricket"
        case .other: "Other"
        default: "Workout"
        }
    }
}
