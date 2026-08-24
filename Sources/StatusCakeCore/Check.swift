import Foundation

/// One StatusCake uptime check, normalized from whatever shape the API
/// actually sent. Every field here is the tolerant reading, not the raw one:
/// see `normalizeCheck` for the reasoning behind each conversion.
public struct Check: Equatable, Sendable {
    public enum Status: String, Equatable, Sendable {
        case up, down, unknown
    }

    public let id: String
    public let name: String
    public let url: String
    public let testType: String
    public let status: Status
    public let paused: Bool
    public let uptime: Double?
    public let tags: [String]
}

/// A paused check is never "down" or "up" for counting or sorting purposes,
/// whatever its last-known `status` field says: pausing a failing check must
/// not read as either an outage or a recovery.
public func isPaused(_ check: Check) -> Bool {
    check.paused
}

public func isDown(_ check: Check) -> Bool {
    !isPaused(check) && check.status == .down
}

public func isUp(_ check: Check) -> Bool {
    !isPaused(check) && check.status == .up
}

/// Reads one element of the API's `data` array. Returns `nil` for anything
/// that is not a JSON object, mirroring the reference's `normalizeCheck`,
/// which drops a malformed entry rather than failing the whole page.
func normalizeCheck(from value: JSONValue) -> Check? {
    guard let raw = value.objectValue else { return nil }

    let statusString = (raw["status"]?.looseString ?? "").lowercased()
    let status: Check.Status = statusString == "up" || statusString == "down"
        ? Check.Status(rawValue: statusString)!
        : .unknown

    let tags: [String]
    if let array = raw["tags"]?.arrayValue {
        tags = array.compactMap(\.looseString)
    } else {
        tags = []
    }

    return Check(
        id: raw["id"]?.looseString ?? "",
        name: raw["name"]?.looseString ?? "",
        url: raw["website_url"]?.looseString ?? "",
        testType: raw["test_type"]?.looseString ?? "",
        status: status,
        paused: raw["paused"]?.isTrue ?? false,
        uptime: raw["uptime"]?.looseDouble,
        tags: tags
    )
}

/// Down first (what the user opened the app for), then up, then paused;
/// alphabetical within each group so the list does not reshuffle between
/// refreshes when nothing has actually changed.
public func sortChecks(_ checks: [Check]) -> [Check] {
    func rank(_ check: Check) -> Int {
        if isPaused(check) { return 2 }
        if isDown(check) { return 0 }
        return 1
    }
    return checks.sorted { a, b in
        let ra = rank(a), rb = rank(b)
        if ra != rb { return ra < rb }
        return a.name.localizedCompare(b.name) == .orderedAscending
    }
}
