import Foundation

/// One page of `GET /v1/uptime`, decoded just far enough to keep paginating
/// and to hand each element to `normalizeCheck`. Anything that is not a JSON
/// object at the top level is a parse failure; a missing or non-array `data`
/// is treated as no checks, matching the reference's tolerance for a response
/// shaped slightly differently than expected.
struct APIPage {
    let checks: [JSONValue]
    let pageCount: Int?
}

func parsePage(_ data: Data) -> Result<APIPage, APIError> {
    guard let value = try? JSONDecoder().decode(JSONValue.self, from: data),
          let object = value.objectValue else {
        return .failure(.parse)
    }

    let checks = object["data"]?.arrayValue ?? []

    var pageCount: Int?
    if let metadata = object["metadata"]?.objectValue,
       let count = metadata["page_count"]?.looseDouble {
        pageCount = Int(count)
    }

    return .success(APIPage(checks: checks, pageCount: pageCount))
}

/// Talks to `GET https://api.statuscake.com/v1/uptime`. Every decision about
/// what the data means lives in the free functions elsewhere in this module;
/// this type's only job is fetching pages and turning transport failures into
/// `APIError`.
public struct StatusCakeAPIClient: Sendable {
    private let session: URLSession
    private let tokenSources: [TokenSource]
    private let baseURL: URL

    /// The API caps `limit` at 100. `maxPages` is a runaway guard, not a
    /// realistic account size: 50 pages is 5000 checks, and it exists so a
    /// malformed or lying `page_count` cannot loop the client forever.
    private let pageLimit = 100
    private let maxPages = 50

    public init(
        session: URLSession = .shared,
        tokenSources: [TokenSource] = [EnvironmentTokenSource()],
        baseURL: URL = URL(string: "https://api.statuscake.com/v1/uptime")!
    ) {
        self.session = session
        self.tokenSources = tokenSources
        self.baseURL = baseURL
    }

    public func resolvedTokenStatus() -> TokenStatus {
        resolveToken(from: tokenSources)?.status ?? .none
    }

    /// Fetches every uptime check, paginating until the API's own
    /// `page_count` says there are no more. `tags` is tolerant input (spaces,
    /// duplicates, empty slots); `matchAny` is only sent when there are tags
    /// to match against, since the API rejects `matchany` with none.
    public func fetchChecks(tags: String = "", matchAny: Bool = false) async -> Result<[Check], APIError> {
        guard let (token, _) = resolveToken(from: tokenSources) else {
            return .failure(.noToken)
        }

        let normalizedTags = tagList(tags).joined(separator: ",")

        var allChecks: [JSONValue] = []
        var page = 1

        pagingLoop: while page <= maxPages {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            var query = [
                URLQueryItem(name: "limit", value: String(pageLimit)),
                URLQueryItem(name: "page", value: String(page))
            ]
            if !normalizedTags.isEmpty {
                query.append(URLQueryItem(name: "tags", value: normalizedTags))
                if matchAny {
                    query.append(URLQueryItem(name: "matchany", value: "true"))
                }
            }
            components.queryItems = query

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                return .failure(.network)
            }

            guard let http = response as? HTTPURLResponse else {
                return .failure(.network)
            }

            switch http.statusCode {
            case 200:
                break
            case 401, 403:
                return .failure(.unauthorized)
            case 429:
                return .failure(.rateLimited)
            default:
                return .failure(.http(http.statusCode))
            }

            switch parsePage(data) {
            case .failure(let error):
                return .failure(error)
            case .success(let apiPage):
                allChecks.append(contentsOf: apiPage.checks)
                let pageCount = apiPage.pageCount ?? 1
                if page >= pageCount { break pagingLoop }
                page += 1
            }
        }

        return .success(allChecks.compactMap(normalizeCheck(from:)))
    }
}
