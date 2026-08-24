import Foundation
import Testing
@testable import StatusCakeCore

/// All tests here share `StubURLProtocol`'s single process-wide responder
/// slot, so the suite is serialized: Swift Testing's default parallelism
/// would otherwise let two tests race on the same mutable static.
@Suite("StatusCakeAPIClient", .serialized)
struct APIClientTests {
    func page(_ checks: [[String: Any]], pageCount: Int) -> Data {
        let body: [String: Any] = [
            "data": checks,
            "metadata": ["page_count": pageCount]
        ]
        return try! JSONSerialization.data(withJSONObject: body)
    }

    func rawCheck(id: String, name: String, status: String, paused: Bool = false, uptime: Double? = 99.9) -> [String: Any] {
        var dict: [String: Any] = ["id": id, "name": name, "status": status, "paused": paused]
        if let uptime { dict["uptime"] = uptime }
        return dict
    }

    func client(tokens: [TokenSource] = [EnvironmentTokenSource(environment: ["STATUSCAKE_API_TOKEN": "test-token"])]) -> StatusCakeAPIClient {
        StatusCakeAPIClient(session: StubURLProtocol.session(), tokenSources: tokens)
    }

    // MARK: - Success

    @Test("a single page of checks is fetched and normalized")
    func singlePageSuccess() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { [self] request in
            .response(.init(statusCode: 200, body: page([
                rawCheck(id: "1", name: "A", status: "up"),
                rawCheck(id: "2", name: "B", status: "down")
            ], pageCount: 1)))
        }
        let result = await client().fetchChecks()
        guard case .success(let checks) = result else {
            Issue.record("expected success")
            return
        }
        #expect(checks.count == 2)
    }

    @Test("multi-page pagination merges every page and stops at page_count")
    func multiPagePagination() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { [self] request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let pageNumber = Int(query.first { $0.name == "page" }?.value ?? "1") ?? 1
            switch pageNumber {
            case 1:
                return .response(.init(statusCode: 200, body: page([
                    rawCheck(id: "1", name: "A", status: "up"),
                    rawCheck(id: "2", name: "B", status: "up")
                ], pageCount: 2)))
            default:
                return .response(.init(statusCode: 200, body: page([
                    rawCheck(id: "3", name: "C", status: "down")
                ], pageCount: 2)))
            }
        }
        let result = await client().fetchChecks()
        guard case .success(let checks) = result else {
            Issue.record("expected success")
            return
        }
        #expect(checks.count == 3)
        #expect(Set(checks.map(\.id)) == ["1", "2", "3"])
        #expect(StubURLProtocol.requests.count == 2)
    }

    @Test("a runaway page_count is capped at 50 pages so the client never loops forever")
    func runawayPageCountCappedAt50() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { [self] request in
            .response(.init(statusCode: 200, body: page([rawCheck(id: "x", name: "X", status: "up")], pageCount: 999)))
        }
        let result = await client().fetchChecks()
        guard case .success(let checks) = result else {
            Issue.record("expected success")
            return
        }
        #expect(checks.count == 50)
        #expect(StubURLProtocol.requests.count == 50)
    }

    @Test("a malformed element in the data array is skipped, not a whole-page failure")
    func malformedElementSkipped() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { [self] request in
            let body: [String: Any] = [
                "data": ["not a check", rawCheck(id: "1", name: "A", status: "up")],
                "metadata": ["page_count": 1]
            ]
            return .response(.init(statusCode: 200, body: try! JSONSerialization.data(withJSONObject: body)))
        }
        let result = await client().fetchChecks()
        guard case .success(let checks) = result else {
            Issue.record("expected success")
            return
        }
        #expect(checks.count == 1)
    }

    @Test("a check with no uptime value is fetched with uptime nil")
    func checkWithNoUptime() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { [self] request in
            .response(.init(statusCode: 200, body: page([rawCheck(id: "1", name: "New", status: "up", uptime: nil)], pageCount: 1)))
        }
        let result = await client().fetchChecks()
        guard case .success(let checks) = result else {
            Issue.record("expected success")
            return
        }
        #expect(checks.first?.uptime == nil)
    }

    // MARK: - Query parameters

    @Test("tags and matchany are only sent when there are tags to match")
    func queryParametersReflectTagsAndMatchAny() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { [self] _ in .response(.init(statusCode: 200, body: page([], pageCount: 1))) }

        _ = await client().fetchChecks(tags: "prod, web", matchAny: true)
        let query = URLComponents(url: StubURLProtocol.requests[0].url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.first { $0.name == "tags" }?.value == "prod,web")
        #expect(query.first { $0.name == "matchany" }?.value == "true")

        StubURLProtocol.requests = []
        _ = await client().fetchChecks(tags: "", matchAny: true)
        let bareQuery = URLComponents(url: StubURLProtocol.requests[0].url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(bareQuery.first { $0.name == "tags" } == nil)
        #expect(bareQuery.first { $0.name == "matchany" } == nil)
    }

    @Test("the token is sent as a bearer header")
    func tokenSentAsBearerHeader() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { [self] _ in .response(.init(statusCode: 200, body: page([], pageCount: 1))) }
        _ = await client().fetchChecks()
        #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    // MARK: - Errors

    @Test("no token in any source yields .noToken without making a request")
    func noTokenAtAll() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { _ in .networkFailure }
        let result = await client(tokens: [EnvironmentTokenSource(environment: [:])]).fetchChecks()
        #expect(result == .failure(.noToken))
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test("HTTP 401 and 403 both yield .unauthorized", arguments: [401, 403])
    func unauthorizedStatusCodes(code: Int) async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { _ in .response(.init(statusCode: code, body: Data())) }
        let result = await client().fetchChecks()
        #expect(result == .failure(.unauthorized))
    }

    @Test("HTTP 429 yields .rateLimited")
    func rateLimited() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { _ in .response(.init(statusCode: 429, body: Data())) }
        let result = await client().fetchChecks()
        #expect(result == .failure(.rateLimited))
    }

    @Test("an unexpected HTTP status yields .http with the code")
    func unexpectedHTTPStatus() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { _ in .response(.init(statusCode: 500, body: Data())) }
        let result = await client().fetchChecks()
        #expect(result == .failure(.http(500)))
    }

    @Test("a transport failure yields .network")
    func transportFailure() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { _ in .networkFailure }
        let result = await client().fetchChecks()
        #expect(result == .failure(.network))
    }

    @Test("unparseable JSON yields .parse")
    func unparseableResponse() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { _ in .response(.init(statusCode: 200, body: Data("<html>not json</html>".utf8))) }
        let result = await client().fetchChecks()
        #expect(result == .failure(.parse))
    }

    @Test("a rejected token surfaces through summarize and tokenRejected")
    func rejectedTokenThroughSummary() async {
        StubURLProtocol.requests = []
        StubURLProtocol.responder = { _ in .response(.init(statusCode: 401, body: Data())) }
        let result = await client().fetchChecks()
        let summary = summarize(result)
        #expect(tokenRejected(summary))
        #expect(summary.hasData == false)
    }
}
