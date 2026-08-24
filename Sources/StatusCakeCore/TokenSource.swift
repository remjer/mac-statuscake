import Foundation

/// Where a resolved token came from, named for the wording later shown in
/// settings ("set by $STATUSCAKE_API_TOKEN" vs. "stored in your Keychain").
public struct TokenStatus: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case environment
        case keychain
    }

    public let source: Source?

    public init(source: Source?) {
        self.source = source
    }

    public var ok: Bool { source != nil }

    public static let none = TokenStatus(source: nil)
}

/// One place a token might live. `EnvironmentTokenSource` is the only
/// implementation in phase 1; a `KeychainTokenSource` conforming to this same
/// protocol slots into `resolveToken(from:)` in a later phase without any
/// call site changing.
public protocol TokenSource: Sendable {
    var sourceKind: TokenStatus.Source { get }
    func token() -> String?
}

public struct EnvironmentTokenSource: TokenSource {
    public let sourceKind: TokenStatus.Source = .environment
    private let environment: [String: String]

    /// Takes the environment as a parameter, defaulting to the process's own,
    /// so tests can supply a fake one instead of depending on whatever
    /// happens to be set on the machine running them.
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    public func token() -> String? {
        guard let value = environment["STATUSCAKE_API_TOKEN"], !value.isEmpty else { return nil }
        return value
    }
}

/// Tries each source in order and reports which one, if any, produced a
/// token. $STATUSCAKE_API_TOKEN wins over the Keychain because it is checked
/// first in the list, not because of anything special about environment
/// variables -- the order lives here, once, rather than at every call site.
public func resolveToken(from sources: [TokenSource]) -> (token: String, status: TokenStatus)? {
    for source in sources {
        if let token = source.token() {
            return (token, TokenStatus(source: source.sourceKind))
        }
    }
    return nil
}
