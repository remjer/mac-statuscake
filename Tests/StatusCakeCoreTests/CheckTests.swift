import Testing
@testable import StatusCakeCore

@Suite("Check normalization and formatting")
struct CheckTests {
    @Test("formatUptime keeps 99.99 and 99.87 apart, and flattens a perfect 100")
    func formatUptimeDistinguishesFractional() {
        #expect(formatUptime(99.99) == "99.99%")
        #expect(formatUptime(99.87) == "99.87%")
        #expect(formatUptime(100) == "100%")
        #expect(formatUptime(100.0) == "100%")
    }

    @Test("formatUptime renders an em dash for absent or unparseable values")
    func formatUptimeAbsent() {
        #expect(formatUptime(nil) == "—")
        #expect(formatUptime(Double.nan) == "—")
    }

    @Test("formatUptime rounds before comparing to 100, so a value that rounds up still shows as a flat 100")
    func formatUptimeRoundsBeforeComparing() {
        #expect(formatUptime(99.996) == "100%")
        #expect(formatUptime(99.994) == "99.99%")
    }

    @Test("elide truncates long names with an ellipsis")
    func elideTruncates() {
        #expect(elide("a very long check name indeed", max: 10) == "a very lo…")
        #expect(elide("short", max: 10) == "short")
    }

    @Test("normalizeCheck reads a well-formed check")
    func normalizeCheckWellFormed() {
        let raw = JSONValue.object([
            "id": .number(42),
            "name": .string("API"),
            "website_url": .string("https://example.test"),
            "test_type": .string("HTTP"),
            "status": .string("Up"),
            "paused": .bool(false),
            "uptime": .number(99.5),
            "tags": .array([.string("prod"), .string("web")])
        ])
        let check = normalizeCheck(from: raw)
        #expect(check?.id == "42")
        #expect(check?.name == "API")
        #expect(check?.status == .up)
        #expect(check?.paused == false)
        #expect(check?.uptime == 99.5)
        #expect(check?.tags == ["prod", "web"])
    }

    @Test("normalizeCheck treats an absent uptime as nil, not zero")
    func normalizeCheckNoUptime() {
        let raw = JSONValue.object([
            "id": .string("1"),
            "name": .string("New Check"),
            "status": .string("up")
        ])
        #expect(normalizeCheck(from: raw)?.uptime == nil)
    }

    @Test("normalizeCheck falls back to unknown for an unrecognised status")
    func normalizeCheckUnknownStatus() {
        let raw = JSONValue.object(["id": .string("1"), "status": .string("weird")])
        #expect(normalizeCheck(from: raw)?.status == .unknown)

        let missing = JSONValue.object(["id": .string("2")])
        #expect(normalizeCheck(from: missing)?.status == .unknown)
    }

    @Test("normalizeCheck requires paused to be a literal true")
    func normalizeCheckPausedStrict() {
        let raw = JSONValue.object(["id": .string("1"), "paused": .string("true")])
        #expect(normalizeCheck(from: raw)?.paused == false)
    }

    @Test("normalizeCheck returns nil for a non-object element")
    func normalizeCheckSkipsMalformed() {
        #expect(normalizeCheck(from: .string("not a check")) == nil)
        #expect(normalizeCheck(from: .null) == nil)
    }

    @Test("isDown and isUp exclude paused checks even if status still says down or up")
    func pausedExcludedFromStatus() {
        let raw = JSONValue.object(["id": .string("1"), "status": .string("down"), "paused": .bool(true)])
        let check = normalizeCheck(from: raw)!
        #expect(isPaused(check))
        #expect(!isDown(check))
        #expect(!isUp(check))
    }

    @Test("sortChecks orders down, then up, then paused, alphabetically within each group")
    func sortChecksOrdering() {
        func check(_ name: String, _ status: Check.Status, paused: Bool = false) -> Check {
            Check(id: name, name: name, url: "", testType: "", status: status, paused: paused, uptime: nil, tags: [])
        }
        let checks = [
            check("Zebra", .up),
            check("Beta", .down),
            check("Alpha", .down),
            check("Middle", .unknown, paused: true),
            check("Yankee", .up)
        ]
        let sorted = sortChecks(checks).map(\.name)
        #expect(sorted == ["Alpha", "Beta", "Yankee", "Zebra", "Middle"])
    }

    @Test("distinctTags merges and sorts tags across checks, dropping duplicates")
    func distinctTagsMergesAndSorts() {
        func check(tags: [String]) -> Check {
            Check(id: "x", name: "x", url: "", testType: "", status: .up, paused: false, uptime: nil, tags: tags)
        }
        let checks = [
            check(tags: ["web", "prod"]),
            check(tags: ["staging"]),
            check(tags: ["prod"]),
            check(tags: [])
        ]
        #expect(distinctTags(checks) == ["prod", "staging", "web"])
    }

    @Test("distinctTags on an empty set of checks is empty")
    func distinctTagsEmpty() {
        #expect(distinctTags([]) == [])
    }
}
