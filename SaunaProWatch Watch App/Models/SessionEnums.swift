import Foundation

enum SessionType: String, Codable, CaseIterable {
    case sauna
    case coldPlunge

    var displayName: String {
        switch self {
        case .sauna: "Sauna"
        case .coldPlunge: "Cold Exposure"
        }
    }

    var icon: String {
        switch self {
        case .sauna: "flame.fill"
        case .coldPlunge: "snowflake"
        }
    }
}

enum SessionSource: String, Codable {
    case autoDetected
    case manual
    case csvImport
    case watchApp
}

enum SessionStatus: String, Codable {
    case detected
    case confirmed
    case dismissed
}
