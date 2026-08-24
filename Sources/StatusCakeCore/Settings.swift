import Foundation

/// Settings as the rest of the app should read them: clamped, defaulted, and
/// normalized. Distinct from whatever a settings store hands in, because that
/// store (UserDefaults, a hand-edited file) is not something this module
/// touches.
public struct Settings: Equatable, Sendable {
    public let refreshIntervalSec: Int
    public let tags: String
    public let matchAnyTag: Bool
    public let notify: Bool

    public init(refreshIntervalSec: Int, tags: String, matchAnyTag: Bool, notify: Bool) {
        self.refreshIntervalSec = refreshIntervalSec
        self.tags = tags
        self.matchAnyTag = matchAnyTag
        self.notify = notify
    }
}

/// Whatever a settings store handed in, before `readSettings` has made sense
/// of it. Every field is optional because the store may not have it yet --
/// most importantly, a record written before a key existed must still default
/// the same way a freshly created one does.
public struct RawSettings: Sendable {
    public var refreshIntervalSec: Int?
    public var tags: String?
    public var matchAnyTag: Bool?
    public var notify: Bool?

    public init(refreshIntervalSec: Int? = nil, tags: String? = nil, matchAnyTag: Bool? = nil, notify: Bool? = nil) {
        self.refreshIntervalSec = refreshIntervalSec
        self.tags = tags
        self.matchAnyTag = matchAnyTag
        self.notify = notify
    }
}

/// Reads settings defensively because the underlying store is hand-editable
/// and may predate some of these keys. Booleans default on via `nil`, i.e.
/// "the key is absent" rather than "the key is explicitly false" -- the
/// Optional itself carries the distinction JS makes with `!= false`, so a
/// record written before `notify` existed still defaults to notifying.
public func readSettings(_ raw: RawSettings) -> Settings {
    let seconds = max(60, min(3600, raw.refreshIntervalSec ?? 300))
    let tags = (raw.tags ?? "").trimmingCharacters(in: .whitespaces)
    return Settings(
        refreshIntervalSec: seconds,
        tags: tags,
        matchAnyTag: raw.matchAnyTag ?? true,
        notify: raw.notify ?? true
    )
}

/// Splits a comma-separated tag string tolerantly: "prod, web ,, staging"
/// yields three tags, stray whitespace and empty slots are dropped, and
/// duplicates collapse to their first occurrence.
public func tagList(_ tags: String) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for piece in tags.split(separator: ",", omittingEmptySubsequences: false) {
        let tag = piece.trimmingCharacters(in: .whitespaces)
        if tag.isEmpty || seen.contains(tag) { continue }
        seen.insert(tag)
        out.append(tag)
    }
    return out
}

/// The inverse of `tagList`, and the last place a stray space could survive:
/// the API matches tags literally, so a trailing space would serialize a tag
/// that matches nothing.
public func joinTags(_ values: [String]) -> String {
    tagList(values.joined(separator: ",")).joined(separator: ",")
}

/// What a fetch should actually ask for, given settings. `matchAny` is
/// dropped whenever there are no tags, since the API rejects `matchany` with
/// nothing to match against.
public func fetchParameters(_ settings: Settings) -> (tags: String, matchAny: Bool) {
    guard !settings.tags.isEmpty else { return ("", false) }
    return (settings.tags, settings.matchAnyTag)
}
