import ServiceManagement

/// Unlike `UNUserNotificationCenter`, `SMAppService.mainApp` does not crash
/// on an unbundled binary -- it registers a login item pointing at whatever
/// path is currently running. That is fine for the packaged `.app` this is
/// meant for, but toggling it on while running via `swift run` would point
/// the login item at a transient `.build/` path that breaks on the next
/// rebuild; see the README for why this should only be flipped on from the
/// installed app in /Applications.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Best effort: there is no separate error-reporting surface for
            // this one setting, and a failed toggle is self-evident (the
            // checkbox reverts on next read of `isEnabled`).
        }
    }
}
