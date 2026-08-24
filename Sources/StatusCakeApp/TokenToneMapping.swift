import SwiftUI
import StatusCakeCore

extension TokenTone {
    var color: Color {
        switch self {
        case .ok: return .green
        case .bad: return .red
        case .none, .unknown: return .secondary
        }
    }
}
