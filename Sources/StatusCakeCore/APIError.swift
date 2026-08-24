import Foundation

/// Every way a refresh can fail, as a type code switches on rather than a
/// string it has to match. The cases mirror the reference implementation's
/// slugs (`no_token`, `unauthorized`, `rate_limited`, `network`, `http`,
/// `parse`) so the same failure taxonomy survives the port.
public enum APIError: Error, Equatable, Sendable {
    case noToken
    case unauthorized
    case rateLimited
    case network
    case http(Int)
    case parse

    /// Prose for display. Code, not this, is what callers should branch on.
    public var message: String {
        switch self {
        case .noToken:
            return "No StatusCake API token found. Set $STATUSCAKE_API_TOKEN."
        case .unauthorized:
            return "StatusCake rejected the API token."
        case .rateLimited:
            return "Rate limited by StatusCake; increase the refresh interval."
        case .network:
            return "Could not reach the StatusCake API."
        case .http(let code):
            return "StatusCake returned HTTP \(code)."
        case .parse:
            return "Unparseable response from StatusCake."
        }
    }
}
