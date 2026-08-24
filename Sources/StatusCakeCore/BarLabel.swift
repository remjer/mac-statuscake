import Foundation

/// Absent or unparseable renders as an em dash rather than a misleading 0%: a
/// brand new check can legitimately have no uptime figure yet.
public func formatUptime(_ value: Double?) -> String {
    guard let value, !value.isNaN else { return "—" }
    // Round to the precision actually displayed before comparing to 100:
    // a raw value like 99.996 is below 100 but rounds to "100.00", which is
    // exactly the "100.00" a flat 100 is supposed to avoid.
    let rounded = (value * 100).rounded() / 100
    if rounded >= 100 { return "100%" }
    return String(format: "%.2f%%", rounded)
}

/// Truncates to `max` characters, replacing the tail with an ellipsis so a
/// long check name cannot blow out a notification or tooltip line.
public func elide(_ text: String, max: Int) -> String {
    guard max > 1, text.count > max else { return text }
    return String(text.prefix(max - 1)) + "…"
}

/// A symbolic name for the bar icon. The app layer maps these to SF Symbols;
/// this module only decides which state applies.
public enum BarIcon: Sendable, Equatable {
    case ok
    case down
    case unknown
}

/// What the menu bar item shows: an icon, optional detail text, and whether
/// the state is urgent (down checks exist) or an error (the refresh itself
/// failed). Core decides what to show; the app layer decides how to draw it.
public struct BarLabel: Equatable, Sendable {
    public let icon: BarIcon
    public let detail: String
    public let urgent: Bool
    public let error: Bool
}

public func barLabel(for summary: Summary) -> BarLabel {
    if summary.error != nil {
        return BarLabel(icon: .unknown, detail: "", urgent: false, error: true)
    }
    if !summary.hasData {
        return BarLabel(icon: .unknown, detail: "", urgent: false, error: false)
    }
    if summary.down > 0 {
        return BarLabel(icon: .down, detail: "\(summary.down)/\(summary.total)", urgent: true, error: false)
    }
    return BarLabel(icon: .ok, detail: String(summary.up), urgent: false, error: false)
}

/// The tooltip line(s): the one error a user can fix from here gets its own
/// wording, since repeating a raw fetch failure would say nothing they don't
/// already know (they never set up a token).
public func tooltipText(_ summary: Summary) -> String {
    if summary.error == .noToken {
        return "StatusCake — no API token yet."
    }
    if let error = summary.error {
        return "StatusCake: \(error.message)"
    }
    if !summary.hasData {
        return "StatusCake: loading…"
    }

    var parts = ["\(summary.up) up", "\(summary.down) down"]
    if summary.paused > 0 { parts.append("\(summary.paused) paused") }
    var text = "StatusCake — " + parts.joined(separator: ", ")

    if summary.down > 0 {
        var names: [String] = []
        for check in summary.checks {
            if names.count >= 5 { break }
            if isDown(check) { names.append(elide(check.name, max: 40)) }
        }
        text += "\n" + names.joined(separator: "\n")
        if summary.down > names.count {
            text += "\n+\(summary.down - names.count) more"
        }
    }
    return text
}
