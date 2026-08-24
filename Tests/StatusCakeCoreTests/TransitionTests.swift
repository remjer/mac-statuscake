import Testing
@testable import StatusCakeCore

@Suite("Transitions and notifications")
struct TransitionTests {
    func entry(_ status: Check.Status, name: String = "Check") -> CheckStatusEntry {
        CheckStatusEntry(status: status, name: name)
    }

    @Test("first poll after a restart produces no transitions, since there is no previous snapshot")
    func firstPollAfterRestart() {
        let current: StatusMap = ["1": entry(.down), "2": entry(.up)]
        let transitions = diffTransitions(previous: [:], current: current)
        #expect(transitions.isEmpty)
        #expect(notificationFor(transitions) == nil)
    }

    @Test("only ids present in both snapshots produce a transition")
    func onlyIdsInBothSnapshotsTransition() {
        let previous: StatusMap = ["1": entry(.up), "2": entry(.down)]
        // id "1" flips, "2" is gone (deleted or paused), "3" is brand new.
        let current: StatusMap = ["1": entry(.down), "3": entry(.up)]
        let transitions = diffTransitions(previous: previous, current: current)
        #expect(transitions.count == 1)
        #expect(transitions[0].id == "1")
        #expect(transitions[0].from == .up)
        #expect(transitions[0].to == .down)
    }

    @Test("a renamed check is still tracked by id")
    func renamedCheckTrackedById() {
        let previous: StatusMap = ["1": entry(.up, name: "Old Name")]
        let current: StatusMap = ["1": entry(.down, name: "New Name")]
        let transitions = diffTransitions(previous: previous, current: current)
        #expect(transitions.count == 1)
        #expect(transitions[0].name == "New Name")
    }

    @Test("pausing a down check drops it from the snapshot, so it never reads as a recovery")
    func pausingDownCheckIsNotRecovery() {
        let previous: StatusMap = ["1": entry(.down)]
        // The check is now paused; statusMap would have dropped it entirely,
        // so the current snapshot simply lacks the id.
        let current: StatusMap = [:]
        let transitions = diffTransitions(previous: previous, current: current)
        #expect(transitions.isEmpty)
    }

    @Test("statusMap drops paused checks and non up/down statuses")
    func statusMapDropsPausedAndUnknown() {
        let summary = Summary(
            error: nil, total: 1, up: 1, down: 0, paused: 1,
            checks: [
                Check(id: "1", name: "Up", url: "", testType: "", status: .up, paused: false, uptime: nil, tags: []),
                Check(id: "2", name: "Paused", url: "", testType: "", status: .down, paused: true, uptime: nil, tags: []),
                Check(id: "3", name: "Unknown", url: "", testType: "", status: .unknown, paused: false, uptime: nil, tags: [])
            ],
            hasData: true
        )
        let map = statusMap(summary)
        #expect(map.count == 1)
        #expect(map["1"]?.status == .up)
        #expect(map["2"] == nil)
        #expect(map["3"] == nil)
    }

    @Test("a single check going down names it")
    func singleDownNotification() {
        let transitions = [Transition(id: "1", name: "API", from: .up, to: .down)]
        let notification = notificationFor(transitions)
        #expect(notification?.body == "API is DOWN")
        #expect(notification?.urgent == true)
    }

    @Test("a single recovery names it")
    func singleRecoveryNotification() {
        let transitions = [Transition(id: "1", name: "API", from: .down, to: .up)]
        let notification = notificationFor(transitions)
        #expect(notification?.body == "API recovered")
        #expect(notification?.urgent == false)
    }

    @Test("twenty checks failing at once collapses to one notification with counts")
    func manySimultaneousDownsCollapse() {
        let transitions = (1...20).map { Transition(id: "\($0)", name: "Check \($0)", from: .up, to: .down) }
        let notification = notificationFor(transitions)
        #expect(notification?.body == "20 down")
        #expect(notification?.urgent == true)
    }

    @Test("a mix of downs and recoveries in one refresh collapses to counts")
    func mixedTransitionsCollapse() {
        let transitions = [
            Transition(id: "1", name: "A", from: .up, to: .down),
            Transition(id: "2", name: "B", from: .up, to: .down),
            Transition(id: "3", name: "C", from: .down, to: .up)
        ]
        let notification = notificationFor(transitions)
        #expect(notification?.body == "2 down, 1 recovered")
        #expect(notification?.urgent == true)
    }

    @Test("no transitions means no notification")
    func noTransitionsNoNotification() {
        #expect(notificationFor([]) == nil)
    }
}
