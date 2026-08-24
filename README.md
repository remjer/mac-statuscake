# mac-statuscake

A macOS port of [omarchy-statuscake](https://github.com/robinvanderknaap/omarchy-statuscake)
by Robin van der Knaap (MIT licensed) — a Linux shell bar widget showing the
status of your [StatusCake](https://www.statuscake.com/) uptime checks. No
code survives the port; the reference's `Model.js` is the specification for
behaviour, rewritten here as native Swift.

This is **phase 4**: the core logic and tests (phase 1), the menu bar app
with polling (phase 2), Keychain token storage and settings (phase 3), plus
transition tracking, wake-from-sleep handling, and a real per-account tag
picker. Notification *delivery* is wired up but inert until phase 5 packages
this as a real `.app` — see "Notifications" below for why. See "Not built
yet" for the rest.

## Build

```bash
swift build
```

Requires Swift 6 and macOS 14+. No third-party dependencies.

## Test

```bash
swift test
```

Runs entirely offline against a stubbed `URLProtocol` — no test touches the
network, the Keychain, or a real StatusCake account.

## Run the CLI

```bash
STATUSCAKE_API_TOKEN=your-token-here swift run statuscake-cli
```

Create a token at [app.statuscake.com](https://app.statuscake.com/User/Account);
read access to uptime tests is all it needs.

Narrow the result to checks carrying particular tags:

```bash
STATUSCAKE_API_TOKEN=your-token-here swift run statuscake-cli --tags prod,web --match-any
```

`--tags` takes a comma-separated list; `--match-any` matches a check carrying
*any* of the tags instead of requiring *all* of them.

## Run the menu bar app

```bash
STATUSCAKE_API_TOKEN=your-token-here swift run StatusCakeApp
```

It puts an icon in the menu bar (no Dock icon, no app switcher entry) and
polls at the configured interval (5 minutes by default). Interactions:

| | |
|---|---|
| Left click | toggle a popover listing every check, down first |
| Middle click | force a refresh |
| Right click | open app.statuscake.com in your browser |
| Cog in the popover | open settings |
| `Esc` | leave settings, or close the popover when the check list is up |

Quit with Ctrl+C in the terminal for now — a Quit menu item arrives with the
app bundle in a later phase.

### Setting the token

The first time there's no token anywhere, the popover shows "No API token
yet." with a button straight into settings. Paste a token there and press
Save: it's verified against the real API before anything is written, then
stored in the Keychain (service `com.communicatie-cockpit.mac-statuscake`,
account `statuscake-api-token`) — never in `UserDefaults`, never logged.
`$STATUSCAKE_API_TOKEN` still wins over the Keychain if both are set, so
settings hides the Remove button in that case (there'd be nothing to
remove that would actually stop the environment variable from winning).

Settings also has the refresh interval (60–3600s), a tag picker, "match any
tag" (only meaningful once tags are set), and a notify toggle — every
control writes immediately, there's no separate save step for those. The tag
picker lists your account's own tags with a search box, refetched (unfiltered)
every time settings opens, so a tag you just added in StatusCake shows up the
next time you look.

### Notifications

`StatusCakeCore` decides what deserves a notification (one per refresh, never
one per check, and never anything on the first poll after a restart); the
app layer tracks the previous poll's snapshot and asks `notificationFor` on
every successful refresh. Delivery itself goes through `UNUserNotificationCenter`
— which turns out to *crash* (`bundleProxyForCurrentProcess is nil`), not
just silently fail, when called from a binary with no real app bundle. Since
`swift run StatusCakeApp` is still exactly that until phase 5, every call
into `UNUserNotificationCenter` is gated behind `Bundle.main.bundleIdentifier
!= nil` in `NotificationDelivery.swift`: the decision logic runs and is
tested regardless, delivery itself is a deliberate no-op for now, and it
starts working the moment this is a real `.app`.

Wake-from-sleep is handled the same way the reference widget needs it:
polling only happens while the process is awake, so on `NSWorkspace.didWakeNotification`
the app forces an immediate refresh rather than waiting out whatever was left
of the interval when the Mac went to sleep.

## What's here

`StatusCakeApp` is the menu bar app: an `NSStatusItem` (not `MenuBarExtra`,
which cannot distinguish left, middle, and right clicks) whose button reads
`NSApp.currentEvent` to route each click, and an `NSPopover` hosting a
SwiftUI view via `NSHostingController` that switches between the check list
and a settings view in place, matching the reference's own reasoning that
settings don't need a window of their own. `KeychainTokenSource` and
`SettingsStore` are the only places this target touches the Keychain or
`UserDefaults` — everything else renders what `StatusCakeCore` decided.

`StatusCakeCore` is a pure-Foundation package with every decision the app
makes: fetching and paginating the StatusCake API, normalizing whatever shape
a check comes back in, sorting and counting checks, formatting uptime,
diffing two snapshots into transitions, collapsing transitions into one
notification per refresh, and the token/settings logic settings screens will
eventually read from. None of it touches AppKit, SwiftUI, UserDefaults, the
Keychain, or a timer — see `Sources/StatusCakeCore` and its tests in
`Tests/StatusCakeCoreTests`.

`statuscake-cli` is a thin executable over that package, useful for exercising
it against a real account before any UI exists.

## Not built yet

- App bundle, code signing, notarisation, launch at login — and, as a direct
  consequence, actual notification delivery (see "Notifications" above)
