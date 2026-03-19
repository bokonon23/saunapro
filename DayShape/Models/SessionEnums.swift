import Foundation
import SwiftUI

enum SessionType: String, Codable, CaseIterable {
    case sauna
    case coldPlunge
    case exercise
    case swimming

    var displayName: String {
        switch self {
        case .sauna: "Sauna"
        case .coldPlunge: "Cold Exposure"
        case .exercise: "Exercise"
        case .swimming: "Swimming"
        }
    }

    var icon: String {
        switch self {
        case .sauna: "flame.fill"
        case .coldPlunge: "snowflake"
        case .exercise: "figure.run"
        case .swimming: "figure.pool.swim"
        }
    }

    var color: Color {
        switch self {
        case .sauna: .orange
        case .coldPlunge: .cyan
        case .exercise: .green
        case .swimming: .blue
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
