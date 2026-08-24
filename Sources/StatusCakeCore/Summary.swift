import Foundation

/// The whole state of an account as of the last refresh. There is no partial
/// variant: a failed refresh carries `error` and zeroed counts, never a mix of
/// stale data and a new error, so a failure can never be mistaken for "all
/// clear" by code that only checks `down == 0`.
public struct Summary: Equatable, Sendable {
    public let error: APIError?
    public let total: Int
    public let up: Int
    public let down: Int
    public let paused: Int
    public let checks: [Check]
    public let hasData: Bool

    public static let empty = Summary(error: nil, total: 0, up: 0, down: 0, paused: 0, checks: [], hasData: false)
}

/// Turns one fetch attempt into everything the app needs to render. Paused
/// checks are excluded from `total`: `total` is up plus down, health as the
/// user would count it, with paused reported alongside rather than folded in.
public func summarize(_ result: Result<[Check], APIError>) -> Summary {
    switch result {
    case .failure(let error):
        return Summary(error: error, total: 0, up: 0, down: 0, paused: 0, checks: [], hasData: false)
    case .success(let checks):
        var up = 0, down = 0, paused = 0
        for check in checks {
            if isPaused(check) { paused += 1 }
            else if isDown(check) { down += 1 }
            else if isUp(check) { up += 1 }
        }
        return Summary(
            error: nil,
            total: up + down,
            up: up,
            down: down,
            paused: paused,
            checks: sortChecks(checks),
            hasData: true
        )
    }
}
