import Foundation
import SwiftUI

enum SessionType: String, Codable, CaseIterable {
    case sauna
    case coldPlunge
    case exercise

    var displayName: String {
        switch self {
        case .sauna: "Sauna"
        case .coldPlunge: "Cold Exposure"
        case .exercise: "Exercise"
        }
    }

    var icon: String {
        switch self {
        case .sauna: "flame.fill"
        case .coldPlunge: "snowflake"
        case .exercise: "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .sauna: .orange
        case .coldPlunge: .cyan
        case .exercise: .green
        }
    }

    /// Whether this is a core session type (sauna/cold) vs informational (exercise)
    var isTherapy: Bool {
        self == .sauna || self == .coldPlunge
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
