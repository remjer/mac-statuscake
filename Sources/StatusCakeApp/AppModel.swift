import Foundation
import StatusCakeCore

/// Owns the poll loop and the latest `Summary`. There is no settings
/// persistence yet, so the refresh interval is `readSettings`'s own default
/// (300s) rather than anything read from storage -- that arrives in a later
/// phase without this type's call sites changing.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var summary: Summary = .empty {
        didSet { onUpdate?(summary) }
    }

    var onUpdate: ((Summary) -> Void)?

    private let client = StatusCakeAPIClient()
    private var pollTask: Task<Void, Never>?

    /// Starts (or restarts) the poll loop: an immediate fetch, then one every
    /// `refreshIntervalSec`. Restarting is also how a forced refresh works --
    /// it is simpler than threading a "skip to next tick" signal through the
    /// loop, and a manual refresh resetting the clock is a reasonable thing
    /// for a user to expect anyway.
    func start() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                let interval = readSettings(RawSettings()).refreshIntervalSec
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func forceRefresh() {
        start()
    }

    private func refresh() async {
        let result = await client.fetchChecks()
        summary = summarize(result)
    }
}
