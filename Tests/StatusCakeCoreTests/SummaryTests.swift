import Testing
@testable import StatusCakeCore

@Suite("Summarize")
struct SummaryTests {
    func check(_ id: String, _ status: Check.Status, paused: Bool = false, uptime: Double? = 99.9) -> Check {
        Check(id: id, name: id, url: "", testType: "HTTP", status: status, paused: paused, uptime: uptime, tags: [])
    }

    @Test("an account with everything up")
    func everythingUp() {
        let summary = summarize(.success([check("a", .up), check("b", .up), check("c", .up)]))
        #expect(summary.error == nil)
        #expect(summary.hasData)
        #expect(summary.up == 3)
        #expect(summary.down == 0)
        #expect(summary.paused == 0)
        #expect(summary.total == 3)
    }

    @Test("an account with several checks down")
    func severalDown() {
        let summary = summarize(.success([check("a", .down), check("b", .down), check("c", .up)]))
        #expect(summary.down == 2)
        #expect(summary.up == 1)
        #expect(summary.total == 3)
    }

    @Test("paused checks are excluded from the health count but reported separately")
    func pausedExcludedFromTotal() {
        let summary = summarize(.success([check("a", .up), check("b", .down, paused: true), check("c", .up, paused: true, uptime: nil)]))
        #expect(summary.up == 1)
        #expect(summary.down == 0)
        #expect(summary.paused == 2)
        #expect(summary.total == 1)
    }

    @Test("an empty account")
    func emptyAccount() {
        let summary = summarize(.success([]))
        #expect(summary.hasData)
        #expect(summary.total == 0)
        #expect(summary.checks.isEmpty)
    }

    @Test("a check with no uptime value formats as an em dash")
    func noUptimeValue() {
        let summary = summarize(.success([check("a", .up, uptime: nil)]))
        #expect(formatUptime(summary.checks[0].uptime) == "—")
    }

    @Test("a failed refresh never reads as all clear: zeroed counts, empty list, no partial state")
    func failedRefreshNeverAllClear() {
        let summary = summarize(.failure(.network))
        #expect(summary.error == .network)
        #expect(summary.hasData == false)
        #expect(summary.total == 0)
        #expect(summary.up == 0)
        #expect(summary.down == 0)
        #expect(summary.paused == 0)
        #expect(summary.checks.isEmpty)
    }

    @Test("every APIError case surfaces distinctly through summarize", arguments: [
        APIError.noToken, .unauthorized, .rateLimited, .network, .http(500), .parse
    ])
    func everyErrorCase(error: APIError) {
        let summary = summarize(.failure(error))
        #expect(summary.error == error)
        #expect(summary.hasData == false)
    }

    @Test("a rejected token is reported through tokenRejected")
    func rejectedToken() {
        let summary = summarize(.failure(.unauthorized))
        #expect(tokenRejected(summary))
        #expect(!needsToken(summary))
    }

    @Test("a missing token is reported through needsToken")
    func missingToken() {
        let summary = summarize(.failure(.noToken))
        #expect(needsToken(summary))
        #expect(!tokenRejected(summary))
    }
}
