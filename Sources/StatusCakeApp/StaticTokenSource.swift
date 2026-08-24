import StatusCakeCore

/// Wraps a literal token string as a `TokenSource`, so verifying a
/// not-yet-saved candidate token can reuse `StatusCakeAPIClient` exactly as
/// it is rather than growing a second, ad hoc fetch path just for this.
struct StaticTokenSource: TokenSource {
    let sourceKind: TokenStatus.Source
    let value: String

    func token() -> String? { value }
}
