# mac-statuscake

A macOS port of [omarchy-statuscake](https://github.com/robinvanderknaap/omarchy-statuscake)
by Robin van der Knaap (MIT licensed) — a Linux shell bar widget showing the
status of your [StatusCake](https://www.statuscake.com/) uptime checks. No
code survives the port; the reference's `Model.js` is the specification for
behaviour, rewritten here as native Swift.

This is **phase 1**: the core decision logic, its test suite, and a CLI to run
it against a real account. There is no menu bar item, popover, Keychain
storage, or notifications yet — see "Not built yet" below.

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

## What's here

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

- Menu bar item (`NSStatusItem`), popover with the check list, polling
- Keychain-backed token storage, a token entry flow, a settings view
- Notifications, wake-from-sleep handling, a tag picker
- App bundle, code signing, notarisation, launch at login
