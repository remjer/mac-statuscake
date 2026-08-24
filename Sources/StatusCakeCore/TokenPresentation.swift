import Foundation

// --- token state ------------------------------------------------------------
//
// The app learns about the token from its ordinary refresh: no token and a
// rejected token are two of the failure cases `APIError` already carries.
// That means settings can offer to fix the token without any extra API call.

/// Nothing is stored anywhere the fetch looked. The app should open straight
/// into settings for this one, since the check list has nothing to show.
public func needsToken(_ summary: Summary) -> Bool {
    summary.error == .noToken
}

/// A token exists but the API refuses it -- revoked, mistyped, or lacking
/// read access to uptime tests. Worth offering the same form, but not worth
/// hijacking the app: the user may have opened it for something else.
public func tokenRejected(_ summary: Summary) -> Bool {
    summary.error == .unauthorized
}

/// Until a token works there is nothing else in settings worth showing: every
/// other setting shapes a fetch that cannot happen. There is no separate
/// "verified" flag here the way the reference's `--status --no-verify` probe
/// has one -- the only proof this module trusts that a token works is the
/// last poll actually returning data, which `summary` already carries.
public func tokenBlocksSettings(_ summary: Summary, _ status: TokenStatus) -> Bool {
    if needsToken(summary) || tokenRejected(summary) { return true }
    return !status.ok
}

/// Where the token actually lives, as a phrase that finishes a sentence. The
/// wording differs by source on purpose: the environment variable merely
/// sets a token, the Keychain stores one, and the difference matters because
/// the fetch reads the environment first.
public func tokenLocation(_ status: TokenStatus) -> String {
    guard status.ok, let source = status.source else { return "" }
    switch source {
    case .environment: return "set by $STATUSCAKE_API_TOKEN"
    case .keychain: return "stored in your Keychain"
    }
}

public enum TokenTone: Equatable, Sendable {
    case unknown, none, ok, bad
}

/// The one line settings should show above the token field: whether there is
/// a token, whether it is known to work, and where it is. `tone` is what the
/// app colours the line and its icon by -- styling stays there, the decision
/// stays here.
public struct TokenStateInfo: Equatable, Sendable {
    public let tone: TokenTone
    public let icon: BarIcon
    public let text: String
}

/// "Works" is proven by the last poll returning data, not by a separate
/// verification call -- so a token revoked an hour ago shows as rejected the
/// moment the next poll says so, and the claim never costs an extra request.
public func tokenState(_ summary: Summary, _ status: TokenStatus) -> TokenStateInfo {
    guard status.ok else {
        return TokenStateInfo(tone: .none, icon: .unknown, text: "No token stored yet.")
    }

    let where_ = tokenLocation(status)
    if tokenRejected(summary) {
        return TokenStateInfo(tone: .bad, icon: .down, text: "StatusCake rejected the token \(where_).")
    }
    if summary.hasData {
        return TokenStateInfo(tone: .ok, icon: .ok, text: "Token works — \(where_).")
    }

    // Found, but nothing has proved it yet: a first poll still in flight, or
    // one that failed for a reason that is not the token's fault.
    return TokenStateInfo(tone: .none, icon: .unknown, text: where_.prefix(1).uppercased() + where_.dropFirst() + ".")
}

/// Whether settings should offer to delete the stored token. An environment
/// token is not this app's to delete: there is nothing to remove that would
/// stop `$STATUSCAKE_API_TOKEN` from still winning, which is the one outcome
/// that would look like the button did nothing.
public func tokenRemovable(_ status: TokenStatus) -> Bool {
    status.ok && status.source == .keychain
}

/// What removing would actually delete, named so the confirm step says it
/// rather than asking "are you sure?" about an unstated thing.
public func tokenRemoveConfirm(_ status: TokenStatus) -> String {
    guard tokenRemovable(status) else { return "" }
    return "Delete the token from your Keychain?"
}

/// Where a Save would put the token, said before the user commits to it.
public func tokenSaveHint(_ status: TokenStatus) -> String {
    if status.ok, status.source == .environment {
        return "Saving stores a token in your Keychain, but $STATUSCAKE_API_TOKEN keeps winning until you unset it."
    }
    return "Token is verified against the API before it is saved."
}
