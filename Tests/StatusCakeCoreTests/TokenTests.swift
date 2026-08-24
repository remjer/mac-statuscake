import Testing
@testable import StatusCakeCore

@Suite("Token resolution and presentation")
struct TokenTests {
    @Test("EnvironmentTokenSource reads an injected environment, not the real process")
    func environmentTokenSourceIsInjectable() {
        let present = EnvironmentTokenSource(environment: ["STATUSCAKE_API_TOKEN": "abc123"])
        #expect(present.token() == "abc123")

        let absent = EnvironmentTokenSource(environment: [:])
        #expect(absent.token() == nil)

        let blank = EnvironmentTokenSource(environment: ["STATUSCAKE_API_TOKEN": ""])
        #expect(blank.token() == nil)
    }

    @Test("resolveToken tries sources in order and reports which one won")
    func resolveTokenOrder() {
        struct AlwaysNil: TokenSource {
            let sourceKind: TokenStatus.Source = .keychain
            func token() -> String? { nil }
        }
        let env = EnvironmentTokenSource(environment: ["STATUSCAKE_API_TOKEN": "from-env"])
        let resolved = resolveToken(from: [env, AlwaysNil()])
        #expect(resolved?.token == "from-env")
        #expect(resolved?.status.source == .environment)
    }

    @Test("resolveToken returns nil when no source has a token")
    func resolveTokenNoneFound() {
        let env = EnvironmentTokenSource(environment: [:])
        #expect(resolveToken(from: [env]) == nil)
    }

    @Test("needsToken and tokenRejected are mutually exclusive and driven by APIError")
    func needsTokenAndRejected() {
        #expect(needsToken(summarize(.failure(.noToken))))
        #expect(!tokenRejected(summarize(.failure(.noToken))))
        #expect(tokenRejected(summarize(.failure(.unauthorized))))
        #expect(!needsToken(summarize(.failure(.unauthorized))))
        #expect(!needsToken(summarize(.success([]))))
        #expect(!tokenRejected(summarize(.success([]))))
    }

    @Test("tokenBlocksSettings is true with no token, a rejected token, or no token status at all")
    func tokenBlocksSettingsCases() {
        #expect(tokenBlocksSettings(summarize(.failure(.noToken)), .none))
        #expect(tokenBlocksSettings(summarize(.failure(.unauthorized)), TokenStatus(source: .environment)))
        #expect(tokenBlocksSettings(summarize(.success([])), .none))
        #expect(!tokenBlocksSettings(summarize(.success([])), TokenStatus(source: .environment)))
    }

    @Test("tokenLocation names the source in a sentence-final phrase")
    func tokenLocationWording() {
        #expect(tokenLocation(TokenStatus(source: .environment)) == "set by $STATUSCAKE_API_TOKEN")
        #expect(tokenLocation(TokenStatus(source: .keychain)) == "stored in your Keychain")
        #expect(tokenLocation(.none) == "")
    }

    @Test("tokenState reads 'works' only once the last poll actually returned data")
    func tokenStateProvenByData() {
        let status = TokenStatus(source: .environment)

        let noneStored = tokenState(summarize(.failure(.noToken)), .none)
        #expect(noneStored.tone == .none)

        let stillLoading = tokenState(Summary.empty, status)
        #expect(stillLoading.tone == .none)
        #expect(stillLoading.text != "")

        let working = tokenState(summarize(.success([])), status)
        #expect(working.tone == .ok)

        let rejected = tokenState(summarize(.failure(.unauthorized)), status)
        #expect(rejected.tone == .bad)
    }

    @Test("only a Keychain-sourced token is removable")
    func tokenRemovableOnlyForKeychain() {
        #expect(!tokenRemovable(TokenStatus(source: .environment)))
        #expect(tokenRemovable(TokenStatus(source: .keychain)))
        #expect(!tokenRemovable(.none))
    }

    @Test("tokenRemoveConfirm is empty unless the token is removable")
    func tokenRemoveConfirmWording() {
        #expect(tokenRemoveConfirm(TokenStatus(source: .environment)) == "")
        #expect(tokenRemoveConfirm(TokenStatus(source: .keychain)) == "Delete the token from your Keychain?")
    }

    @Test("tokenSaveHint warns that the environment variable keeps winning")
    func tokenSaveHintWording() {
        #expect(tokenSaveHint(TokenStatus(source: .environment)).contains("$STATUSCAKE_API_TOKEN"))
        #expect(tokenSaveHint(.none) == "Token is verified against the API before it is saved.")
    }
}
