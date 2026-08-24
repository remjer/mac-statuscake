import AppKit
import StatusCakeCore

/// `StatusCakeCore` decides *which* symbolic icon a state calls for; this is
/// the one place that turns that decision into an actual SF Symbol name.
extension BarIcon {
    var sfSymbolName: String {
        switch self {
        case .ok: return "checkmark.circle"
        case .down: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

extension Check.Status {
    var sfSymbolName: String {
        switch self {
        case .up: return "checkmark.circle"
        case .down: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
