import Foundation

/// What a check's status was as of one refresh, for comparing against the
/// next one.
public struct CheckStatusEntry: Equatable, Sendable {
    public let status: Check.Status
    public let name: String
}

/// A snapshot keyed by check id, not name, so a rename does not look like a
/// deletion plus a new check. Paused checks are dropped entirely: pausing a
/// down check must never read as a recovery on the next refresh.
public typealias StatusMap = [String: CheckStatusEntry]

public func statusMap(_ summary: Summary) -> StatusMap {
    var out: StatusMap = [:]
    for check in summary.checks {
        guard !isPaused(check) else { continue }
        guard check.status == .up || check.status == .down else { continue }
        out[check.id] = CheckStatusEntry(status: check.status, name: check.name)
    }
    return out
}

public struct Transition: Equatable, Sendable {
    public let id: String
    public let name: String
    public let from: Check.Status
    public let to: Check.Status
}

/// Only ids present in BOTH snapshots produce a transition. A check that is
/// new, deleted, or newly unpaused is not an event -- otherwise the first
/// poll after a restart would replay every check's status as if it just
/// changed.
public func diffTransitions(previous: StatusMap, current: StatusMap) -> [Transition] {
    var out: [Transition] = []
    for (id, next) in current {
        guard let prev = previous[id] else { continue }
        guard prev.status != next.status else { continue }
        out.append(Transition(id: id, name: next.name, from: prev.status, to: next.status))
    }
    return out.sorted { a, b in
        if a.to != b.to { return a.to == .down }
        return a.name.localizedCompare(b.name) == .orderedAscending
    }
}

public struct StatusNotification: Equatable, Sendable {
    public let title: String
    public let body: String
    public let urgent: Bool
}

/// One notification per refresh, not one per check: twenty checks failing at
/// once from a single provider outage should read as one notification, not
/// twenty.
public func notificationFor(_ transitions: [Transition]) -> StatusNotification? {
    guard !transitions.isEmpty else { return nil }

    let downs = transitions.filter { $0.to == .down }
    let ups = transitions.filter { $0.to == .up }

    if downs.count == 1, ups.isEmpty {
        return StatusNotification(title: "StatusCake", body: "\(elide(downs[0].name, max: 60)) is DOWN", urgent: true)
    }
    if ups.count == 1, downs.isEmpty {
        return StatusNotification(title: "StatusCake", body: "\(elide(ups[0].name, max: 60)) recovered", urgent: false)
    }

    var parts: [String] = []
    if !downs.isEmpty { parts.append("\(downs.count) down") }
    if !ups.isEmpty { parts.append("\(ups.count) recovered") }
    return StatusNotification(title: "StatusCake", body: parts.joined(separator: ", "), urgent: !downs.isEmpty)
}
