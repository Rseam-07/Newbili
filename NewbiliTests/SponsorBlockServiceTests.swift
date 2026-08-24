import Foundation
import XCTest
@testable import bili

final class SponsorBlockServiceTests: XCTestCase {
    func testDecodesAndSortsOnlySkippableSegments() throws {
        let data = try XCTUnwrap(
            """
            [
              {"cid":"168885122","category":"sponsor","actionType":"skip","segment":[30.5,40.0],"UUID":"second","videoDuration":1801,"votes":2},
              {"cid":"168885122","category":"intro","actionType":"skip","segment":[0,12.25],"UUID":"first","videoDuration":1801,"votes":1},
              {"cid":"168885122","category":"poi_highlight","actionType":"poi","segment":[20,20],"UUID":"point","videoDuration":1801,"votes":1},
              {"cid":"168885122","category":"outro","actionType":"mute","segment":[50,60],"UUID":"mute","videoDuration":1801,"votes":1}
            ]
            """.data(using: .utf8)
        )

        let segments = try SponsorBlockService.decodeSegments(from: data)

        XCTAssertEqual(segments.map(\.id), ["first", "second"])
        XCTAssertEqual(segments.map(\.title), ["开场", "赞助"])
        XCTAssertEqual(segments[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(segments[0].endTime, 12.25, accuracy: 0.001)
    }

    func testMissingActionTypeDefaultsToSkip() throws {
        let data = try XCTUnwrap(
            """
            [{"cid":"1","category":"selfpromo","segment":[2,8],"UUID":"legacy","videoDuration":10,"votes":0}]
            """.data(using: .utf8)
        )

        let segment = try XCTUnwrap(SponsorBlockService.decodeSegments(from: data).first)

        XCTAssertTrue(segment.isSkippable)
        XCTAssertEqual(segment.title, "推广")
    }

    func testPreferencesMatchPiliPlusDefaultsAndRespectOverrides() {
        let defaults = SponsorBlockPreferences.default

        for category in SponsorBlockCategory.allCases {
            XCTAssertEqual(defaults.behavior(for: category.rawValue), .skipOnce)
        }

        var customized = defaults
        customized.categoryBehaviors[SponsorBlockCategory.sponsor.rawValue] = .skipManually
        customized.minimumSegmentDuration = 5

        XCTAssertEqual(customized.behavior(for: "sponsor", duration: 12), .skipManually)
        XCTAssertEqual(customized.behavior(for: "sponsor", duration: 2), .showOnly)
        XCTAssertEqual(customized.behavior(for: "INTRO", duration: 8), .skipOnce)
    }

    func testPreferencesNormalizeDurationAndCustomServer() {
        let preferences = SponsorBlockPreferences(
            minimumSegmentDuration: 240,
            customServerURL: "  https://example.com/sponsor/  "
        ).normalized

        XCTAssertEqual(preferences.minimumSegmentDuration, 120)
        XCTAssertEqual(preferences.customServerURL, "https://example.com/sponsor/")
        XCTAssertEqual(preferences.serverURL?.absoluteString, "https://example.com/sponsor/")

        XCTAssertNil(SponsorBlockPreferences(customServerURL: "file:///tmp/server").serverURL)
        XCTAssertNil(SponsorBlockPreferences(customServerURL: "not a url").serverURL)
    }

    @MainActor
    func testLibraryStorePersistsSponsorBlockPreferencesAndAnimeMarks() throws {
        let suiteName = "SponsorBlockServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LibraryStore(userDefaults: defaults)
        var preferences = SponsorBlockPreferences.default
        preferences.categoryBehaviors[SponsorBlockCategory.outro.rawValue] = .showOnly
        preferences.minimumSegmentDuration = 7
        preferences.trackingEnabled = false

        store.setSponsorBlockEnabled(true)
        store.setSponsorBlockPreferences(preferences)
        store.setVideoMarkedAsAnime("  bv1pj411h7jl ", isMarked: true)

        let restored = LibraryStore(userDefaults: defaults)
        XCTAssertTrue(restored.sponsorBlockEnabled)
        XCTAssertEqual(restored.sponsorBlockPreferences, preferences)
        XCTAssertTrue(restored.isVideoMarkedAsAnime("BV1PJ411H7JL"))

        restored.setVideoMarkedAsAnime("bv1pj411h7jl", isMarked: false)
        XCTAssertFalse(LibraryStore(userDefaults: defaults).isVideoMarkedAsAnime("BV1PJ411H7JL"))
    }
}
