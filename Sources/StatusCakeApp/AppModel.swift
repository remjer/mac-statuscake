import Foundation
import StatusCakeCore

/// Owns the poll loop, the latest `Summary`, settings, and the token
/// lifecycle. Everything it *decides* -- token wording, whether settings are
/// blocked, what to fetch -- comes from `StatusCakeCore`; this type only
/// wires that into the Keychain, `UserDefaults`, and the network.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var summary: Summary = .empty {
        didSet { onUpdate?(summary) }
    }
    @Published private(set) var tokenStatus: TokenStatus = .none
    @Published var settings: Settings = SettingsStore.load()
    @Published var showingSettings = false

    var onUpdate: ((Summary) -> Void)?

    private let client = StatusCakeAPIClient(tokenSources: [EnvironmentTokenSource(), KeychainTokenSource()])
    private var pollTask: Task<Void, Never>?

    /// The last successful poll's snapshot, for diffing against the next one.
    /// Only ever replaced by a *successful* fetch: a transient failure must
    /// not reset this to empty, or the next successful poll would compare
    /// against nothing and silently drop whatever really changed while the
    /// fetch was failing.
    private var previousStatusMap: StatusMap = [:]

    var tokenStateInfo: TokenStateInfo { tokenState(summary, tokenStatus) }
    var settingsBlocked: Bool { tokenBlocksSettings(summary, tokenStatus) }
    var tokenIsRemovable: Bool { tokenRemovable(tokenStatus) }
    var tokenRemoveConfirmText: String { tokenRemoveConfirm(tokenStatus) }
    var tokenSaveHintText: String { tokenSaveHint(tokenStatus) }

    /// Starts (or restarts) the poll loop: an immediate fetch, then one every
    /// `refreshIntervalSec`. Restarting is also how a forced refresh and a
    /// settings change both take effect immediately, rather than waiting out
    /// whatever was left of the previous interval.
    func start() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(settings.refreshIntervalSec))
            }
        }
    }

    func forceRefresh() {
        start()
    }

    private func refresh() async {
        tokenStatus = client.resolvedTokenStatus()
        let parameters = fetchParameters(settings)
        let result = await client.fetchChecks(tags: parameters.tags, matchAny: parameters.matchAny)
        let newSummary = summarize(result)

        if newSummary.hasData {
            let current = statusMap(newSummary)
            let transitions = diffTransitions(previous: previousStatusMap, current: current)
            if settings.notify, let notification = notificationFor(transitions) {
                NotificationDelivery.deliver(notification)
            }
            previousStatusMap = current
        }

        summary = newSummary
    }

    // MARK: - Tag picker

    /// A fresh, unfiltered fetch merged into the account's distinct tags --
    /// see `distinctTags`' own reasoning for why this must never reuse the
    /// current (possibly tag-filtered) summary.
    func fetchAvailableTags() async -> [String] {
        let result = await client.fetchChecks()
        guard case .success(let checks) = result else { return [] }
        return distinctTags(checks)
    }

    // MARK: - Token entry

    /// Verifies a candidate token against the real API before storing
    /// anything -- the same guarantee the reference implementation makes,
    /// and the reason a bad paste never silently becomes "the" token.
    func saveToken(_ candidate: String) async -> Result<Void, APIError> {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.noToken) }

        let verifier = StatusCakeAPIClient(tokenSources: [StaticTokenSource(sourceKind: .keychain, value: trimmed)])
        let result = await verifier.fetchChecks()
        guard case .success = result else {
            if case .failure(let error) = result { return .failure(error) }
            return .failure(.network)
        }

        KeychainTokenStore.save(trimmed)
        start()
        return .success(())
    }

    func removeToken() async {
        KeychainTokenStore.remove()
        start()
    }

    // MARK: - Settings

    /// Every settings control "writes on the spot" -- there is no separate
    /// save step, so a change takes effect on the very next fetch.
    func updateRefreshIntervalSec(_ value: Int) {
        SettingsStore.setRefreshIntervalSec(value)
        settings = SettingsStore.load()
        start()
    }

    func updateTags(_ value: String) {
        SettingsStore.setTags(value)
        settings = SettingsStore.load()
        start()
    }

    func updateMatchAnyTag(_ value: Bool) {
        SettingsStore.setMatchAnyTag(value)
        settings = SettingsStore.load()
        start()
    }

    func updateNotify(_ value: Bool) {
        SettingsStore.setNotify(value)
        settings = SettingsStore.load()
    }
}
