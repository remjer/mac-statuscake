# mac-statuscake

A native macOS menu bar app for monitoring [StatusCake](https://www.statuscake.com/)
uptime checks — status at a glance, a searchable check list, and desktop
notifications on down/up transitions.

It's a from-scratch Swift port of [omarchy-statuscake](https://github.com/robinvanderknaap/omarchy-statuscake)
by Robin van der Knaap (MIT licensed), a Linux shell bar widget. No code is
reused from that project; its `Model.js` served as the behavioural
specification this was rewritten from.

## Features

- Menu bar status item showing up/down counts, with an urgent (red) state
  when something is down
- Popover check list, sorted down-first, each row showing uptime %
- Keychain-backed API token storage, verified against the real API before
  it's saved
- Settings: refresh interval, a searchable tag picker (filters which checks
  are polled), a notify toggle, and launch-at-login
- Desktop notifications on status transitions — one per refresh, never one
  per check, and never a backlog replay after a restart
- Refreshes immediately on wake from sleep, not just on the next scheduled poll
- A `statuscake-cli` executable for scripting or quick checks from a terminal

## Requirements

- macOS 14+
- Swift 6 toolchain (Xcode 16+, or the Swift 6 command line tools)
- A StatusCake account and an API token with read access to Uptime Tests
  (create one at [app.statuscake.com](https://app.statuscake.com/User/Account))

No third-party dependencies — just Foundation, AppKit, SwiftUI, and Apple's
system frameworks.

## Getting started

```bash
swift build
swift test
```

Tests run entirely offline against a stubbed `URLProtocol` — nothing touches
the network, the Keychain, or a real StatusCake account.

### Run in development

```bash
STATUSCAKE_API_TOKEN=your-token-here swift run StatusCakeApp
```

This runs the bare executable, which is enough to develop against but has
two limitations (see [Notifications](#notifications) and
[Launch at login](#launch-at-login) below): notifications don't fire, and a
login item registered from here would point at a build path that breaks on
the next rebuild. For real use, build the app bundle instead:

```bash
./Scripts/build-app.sh
cp -R .build/StatusCake.app /Applications/
```

See [Building the app bundle](#building-the-app-bundle) for what this
produces and how signing works.

### Run the CLI

A thin, headless client over the same core logic — useful for scripting or
for checking your account without opening the app:

```bash
STATUSCAKE_API_TOKEN=your-token-here swift run statuscake-cli
STATUSCAKE_API_TOKEN=your-token-here swift run statuscake-cli --tags prod,web --match-any
```

`--tags` takes a comma-separated list; `--match-any` matches a check
carrying *any* of the tags instead of requiring *all* of them.

## Usage

| Action | Result |
|---|---|
| Left click | Toggle a popover listing every check, down first |
| Middle click | Force a refresh |
| Right click | Open app.statuscake.com in your browser |
| Cog icon in the popover | Open settings |
| `Esc` | Leave settings, or close the popover when the check list is up |

No Dock icon or app switcher entry — it lives entirely in the menu bar. Quit
from the bottom of settings ("Quit StatusCake"), or Ctrl+C in the terminal if
running via `swift run`.

### Setting up a token

The first time there's no token anywhere, the popover shows "No API token
yet." with a button straight into settings. Paste a token there and press
Save: it's verified against the real API before anything is written, then
stored in the Keychain (service `com.remjer.mac-statuscake`, account
`statuscake-api-token`) — never in `UserDefaults`, never logged.

`$STATUSCAKE_API_TOKEN` takes priority over the Keychain if both are set.
Settings hides the Remove button in that case, since there'd be nothing to
remove that would actually stop the environment variable from winning.

### Settings

- **Refresh interval** — 60–3600 seconds.
- **Tags** — a searchable picker listing your account's own tags, refetched
  (unfiltered) every time settings opens, so a tag just added in StatusCake
  shows up immediately rather than after the next poll.
- **Match any tag** — matches a check carrying *any* selected tag instead of
  requiring *all* of them. Disabled while no tags are selected, since the API
  rejects that combination.
- **Notify on status change** — see below.
- **Launch at login** — see below.

Every control writes immediately; there's no separate save step for any of
these.

### Notifications

One notification per refresh, never one per check — twenty checks going down
from the same outage is one notification, not twenty. Nothing fires on the
first poll after a restart, since there's no prior state yet to diff against.

Delivery goes through `UNUserNotificationCenter`, which only works from a
real, signed app bundle — calling it from a bare `swift run` binary *crashes*
the process (`bundleProxyForCurrentProcess is nil`), it doesn't just silently
fail. Every call site is gated behind a bundle-identifier check, so running
via `swift run` is safe but delivers no notifications; build and run the
`.app` (see below) to get real ones.

### Launch at login

Backed by `SMAppService.mainApp`. Unlike notifications, this works even from
an unbundled binary — which is exactly the problem: toggling it on while
running via `swift run` registers a login item pointing at a `.build/` path
that breaks on the next rebuild. Only enable it from the installed `.app` in
`/Applications`.

## Building the app bundle

```bash
./Scripts/build-app.sh
```

Produces `.build/StatusCake.app`: a release build wrapped with `Info.plist`
(`LSUIElement`, so it never shows a Dock icon), a generated icon
(`Scripts/generate-icon.swift`), and a code signature. Move it to
`/Applications` to use it day to day.

**Code signing:** the script defaults to ad-hoc signing (`codesign --sign -`),
which is enough to run on the machine that built it — Gatekeeper will still
warn once on first launch since the build isn't notarized. To distribute the
app to other Macs, set two environment variables before running the script:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE_PROFILE="your-notarytool-profile" \
./Scripts/build-app.sh
```

This requires a paid Apple Developer Program membership, a Developer ID
Application certificate, and notarization credentials stored via
`xcrun notarytool store-credentials`. Nothing else about the build changes.

## Architecture

```
Sources/
  StatusCakeCore/     Pure Foundation package — every decision the app makes
  StatusCakeApp/       AppKit + SwiftUI menu bar app
  statuscake-cli/      Headless CLI over StatusCakeCore
Tests/
  StatusCakeCoreTests/ Full coverage of StatusCakeCore, network-stubbed
Resources/              Info.plist, app icon
Scripts/                Icon generation, app bundle packaging
```

**`StatusCakeCore`** contains every decision the app makes, as pure,
independently-testable functions: fetching and paginating the StatusCake
API, normalizing whatever shape a check comes back in, sorting and counting
checks, formatting uptime, diffing two snapshots into transitions,
collapsing transitions into a single notification, and the token/settings
logic the UI reads from. It depends only on Foundation — no AppKit, SwiftUI,
UserDefaults, Keychain, or timers — which is what makes states like "several
checks down" or "the API rejected the token" testable without a live
StatusCake account.

**`StatusCakeApp`** is the thin layer that renders what Core decided: an
`NSStatusItem` (not `MenuBarExtra`, which can't distinguish left, middle, and
right clicks) whose button reads `NSApp.currentEvent` to route each click,
and an `NSPopover` hosting a SwiftUI view via `NSHostingController` that
switches between the check list and settings in place. `KeychainTokenSource`
and `SettingsStore` are the only places this target touches the Keychain or
`UserDefaults`.

**`statuscake-cli`** is a minimal executable over the same `StatusCakeCore`
package, useful for exercising it against a real account without any UI.

### Testing

`swift test` runs entirely offline: a `URLProtocol` stub replaces the
network layer, so tests can exercise the states that matter most and rarely
occur naturally on a healthy account — several checks down, paused checks,
every API error including a rejected token, multi-page pagination, and every
transition scenario (a restart producing no notifications is the important
one). No test touches the network, the Keychain, or a real account.

## Known limitations

- No Developer ID signing or notarization by default — see
  [Building the app bundle](#building-the-app-bundle) for how to add it.
- The app icon is a generated placeholder (`Scripts/generate-icon.swift`),
  not a designed one.

## Credits

Ported from [omarchy-statuscake](https://github.com/robinvanderknaap/omarchy-statuscake)
by Robin van der Knaap, which supplied the behavioural specification this
was rewritten from. No code from that project is included here.

## License

MIT — see [LICENSE](LICENSE).
