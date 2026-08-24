import Foundation
import StatusCakeCore

func printUsage() {
    print("""
    Usage: statuscake-cli [--tags LIST] [--match-any]

      --tags LIST    Comma-separated tags; only checks carrying them are shown.
      --match-any    Match checks carrying ANY of --tags instead of all of them.

    Reads the API token from $STATUSCAKE_API_TOKEN.
    """)
}

func statusMarker(for check: Check) -> String {
    if isPaused(check) { return "‖" }
    if isDown(check) { return "✕" }
    if isUp(check) { return "✓" }
    return "?"
}

func render(_ summary: Summary) -> String {
    if let error = summary.error {
        return "StatusCake: \(error.message)"
    }
    if !summary.hasData {
        return "StatusCake: no data"
    }

    var parts = ["\(summary.up) up", "\(summary.down) down"]
    if summary.paused > 0 { parts.append("\(summary.paused) paused") }

    var lines = ["StatusCake — " + parts.joined(separator: ", "), ""]
    for check in summary.checks {
        lines.append("\(statusMarker(for: check)) \(check.name) — \(formatUptime(check.uptime))")
    }
    return lines.joined(separator: "\n")
}

var tags = ""
var matchAny = false
var arguments = Array(CommandLine.arguments.dropFirst())
var index = 0
while index < arguments.count {
    switch arguments[index] {
    case "--tags":
        guard index + 1 < arguments.count else {
            print("error: --tags needs a value")
            exit(1)
        }
        tags = arguments[index + 1]
        index += 2
    case "--match-any":
        matchAny = true
        index += 1
    case "-h", "--help":
        printUsage()
        exit(0)
    default:
        print("error: unknown option: \(arguments[index])")
        printUsage()
        exit(1)
    }
}

let client = StatusCakeAPIClient()
let result = await client.fetchChecks(tags: tags, matchAny: matchAny)
let summary = summarize(result)
print(render(summary))
exit(summary.error == nil ? 0 : 1)
