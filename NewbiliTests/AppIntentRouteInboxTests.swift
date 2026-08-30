import XCTest
@testable import bili

final class AppIntentRouteInboxTests: XCTestCase {
    @MainActor
    func testInboxPersistsOnlyLatestDestinationUntilAcknowledged() throws {
        let suiteName = "AppIntentRouteInboxTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let secondID = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        let inbox = AppIntentRouteInbox(userDefaults: defaults, now: { now })
        inbox.enqueue(.history, createdAt: now.addingTimeInterval(-2))
        inbox.enqueue(
            .video(bvid: "BV14Q4y1z7bW"),
            id: secondID,
            createdAt: now.addingTimeInterval(-1)
        )

        let restored = AppIntentRouteInbox(userDefaults: defaults, now: { now })
        XCTAssertEqual(restored.requests.map(\.id), [secondID])
        XCTAssertEqual(restored.pendingRequest?.route, .video(bvid: "BV14Q4y1z7bW"))

        restored.acknowledge(secondID)
        XCTAssertTrue(restored.requests.isEmpty)
        XCTAssertNil(defaults.data(forKey: "app-intent-route-inbox-v1"))
    }

    @MainActor
    func testInboxDropsExpiredColdStartRequest() throws {
        let suiteName = "AppIntentRouteInboxTests.Expiration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stored = [
            AppIntentRouteRequest(
                route: .history,
                createdAt: Date(timeIntervalSince1970: 100)
            )
        ]
        defaults.set(try JSONEncoder().encode(stored), forKey: "app-intent-route-inbox-v1")

        let inbox = AppIntentRouteInbox(
            userDefaults: defaults,
            requestLifetime: 300,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
        XCTAssertTrue(inbox.requests.isEmpty)
        XCTAssertNil(defaults.data(forKey: "app-intent-route-inbox-v1"))
    }

    func testVideoIdentifierAcceptsBareBVIDAndBilibiliURL() {
        XCTAssertEqual(
            AppIntentVideoIdentifier.normalizedBVID(from: "BV14Q4y1z7bW"),
            "BV14Q4y1z7bW"
        )
        XCTAssertEqual(
            AppIntentVideoIdentifier.normalizedBVID(
                from: "https://www.bilibili.com/video/BV1Ax4y1p7bT/?spm_id_from=333"
            ),
            "BV1Ax4y1p7bT"
        )
        XCTAssertEqual(
            AppIntentVideoIdentifier.normalizedBVID(from: "bv1hz4y157kz"),
            "BV1hz4y157kz"
        )
    }

    func testVideoIdentifierRejectsMalformedInput() {
        XCTAssertNil(AppIntentVideoIdentifier.normalizedBVID(from: ""))
        XCTAssertNil(AppIntentVideoIdentifier.normalizedBVID(from: "AV123456"))
        XCTAssertNil(AppIntentVideoIdentifier.normalizedBVID(from: "BV123"))
        XCTAssertNil(AppIntentVideoIdentifier.normalizedBVID(from: "not-a-video"))
    }

    func testAppleIntelligenceStatusAlwaysProvidesHonestAvailabilityCopy() {
        let status = AppleIntelligenceAvailabilityService.current()

        XCTAssertFalse(status.title.isEmpty)
        XCTAssertEqual(status.isAvailable, status == .available)
    }
}
