import Foundation

/// A `URLProtocol` stub so `StatusCakeAPIClientTests` never touches the
/// network. `responder` is a single, process-wide slot rather than per-request
/// state, so every test that uses it lives in a `.serialized` suite -- see
/// `APIClientTests`.
final class StubURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let body: Data
    }

    enum Outcome {
        case response(Response)
        case networkFailure
    }

    nonisolated(unsafe) static var responder: (@Sendable (URLRequest) -> Outcome)?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.requests.append(request)
        guard let responder = StubURLProtocol.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        switch responder(request) {
        case .networkFailure:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case .response(let response):
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
