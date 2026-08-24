import Testing
@testable import StatusCakeCore

@Suite("Settings and tags")
struct SettingsTests {
    @Test("refreshIntervalSec is clamped to 60...3600 at read time")
    func refreshIntervalClamped() {
        #expect(readSettings(RawSettings(refreshIntervalSec: 10)).refreshIntervalSec == 60)
        #expect(readSettings(RawSettings(refreshIntervalSec: 999_999)).refreshIntervalSec == 3600)
        #expect(readSettings(RawSettings(refreshIntervalSec: 300)).refreshIntervalSec == 300)
        #expect(readSettings(RawSettings(refreshIntervalSec: nil)).refreshIntervalSec == 300)
    }

    @Test("booleans default on when the key is absent, matching != false rather than == true")
    func booleansDefaultOnWhenAbsent() {
        let defaults = readSettings(RawSettings())
        #expect(defaults.matchAnyTag == true)
        #expect(defaults.notify == true)

        let explicitOff = readSettings(RawSettings(matchAnyTag: false, notify: false))
        #expect(explicitOff.matchAnyTag == false)
        #expect(explicitOff.notify == false)

        let explicitOn = readSettings(RawSettings(matchAnyTag: true, notify: true))
        #expect(explicitOn.matchAnyTag == true)
        #expect(explicitOn.notify == true)
    }

    @Test("tagList is tolerant of spaces, empty slots, and duplicates on the way in")
    func tagListTolerant() {
        #expect(tagList("prod, web ,, staging") == ["prod", "web", "staging"])
        #expect(tagList("prod,prod,web") == ["prod", "web"])
        #expect(tagList("") == [])
        #expect(tagList(",,,") == [])
    }

    @Test("joinTags produces no stray spaces, since the API matches tags literally")
    func joinTagsNoStraySpaces() {
        #expect(joinTags(["prod", "web"]) == "prod,web")
        #expect(joinTags([" prod ", "web", "prod"]) == "prod,web")
        #expect(joinTags([]) == "")
    }

    @Test("fetchParameters drops matchAny when there are no tags, since the API rejects matchany alone")
    func fetchParametersDropsMatchAnyWithoutTags() {
        let noTags = Settings(refreshIntervalSec: 300, tags: "", matchAnyTag: true, notify: true)
        let result = fetchParameters(noTags)
        #expect(result.tags == "")
        #expect(result.matchAny == false)

        let withTags = Settings(refreshIntervalSec: 300, tags: "prod,web", matchAnyTag: true, notify: true)
        let withResult = fetchParameters(withTags)
        #expect(withResult.tags == "prod,web")
        #expect(withResult.matchAny == true)
    }
}
