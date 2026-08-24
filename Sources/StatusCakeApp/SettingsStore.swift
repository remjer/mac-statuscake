import Foundation
import StatusCakeCore

/// The one place this app reads and writes `UserDefaults`. Every read goes
/// through `readSettings`, so the same clamping and "absent means on" default
/// logic `StatusCakeCore` already tests applies here too.
@MainActor
enum SettingsStore {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let refreshIntervalSec = "refreshIntervalSec"
        static let tags = "tags"
        static let matchAnyTag = "matchAnyTag"
        static let notify = "notify"
    }

    static func load() -> Settings {
        var raw = RawSettings()
        if defaults.object(forKey: Key.refreshIntervalSec) != nil {
            raw.refreshIntervalSec = defaults.integer(forKey: Key.refreshIntervalSec)
        }
        raw.tags = defaults.string(forKey: Key.tags)
        // `object(forKey:) != nil` distinguishes "never set" from "set to
        // false" -- UserDefaults.bool(forKey:) alone would collapse both to
        // false and defeat readSettings' != false default-on behaviour.
        if defaults.object(forKey: Key.matchAnyTag) != nil {
            raw.matchAnyTag = defaults.bool(forKey: Key.matchAnyTag)
        }
        if defaults.object(forKey: Key.notify) != nil {
            raw.notify = defaults.bool(forKey: Key.notify)
        }
        return readSettings(raw)
    }

    static func setRefreshIntervalSec(_ value: Int) {
        defaults.set(value, forKey: Key.refreshIntervalSec)
    }

    static func setTags(_ value: String) {
        defaults.set(value, forKey: Key.tags)
    }

    static func setMatchAnyTag(_ value: Bool) {
        defaults.set(value, forKey: Key.matchAnyTag)
    }

    static func setNotify(_ value: Bool) {
        defaults.set(value, forKey: Key.notify)
    }
}
