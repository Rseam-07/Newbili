import Foundation
import XCTest
@testable import bili

final class SponsorBlockServiceTests: XCTestCase {
    override func tearDown() {
        SponsorBlockRetryURLProtocol.reset()
        super.tearDown()
    }

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

    func testSegmentGETRetriesTransientHTTPFailureAndKeeps404Empty() async throws {
        let session = makeRetrySession()
        let service = SponsorBlockService(
            baseURL: try XCTUnwrap(URL(string: "https://sponsor-block.test")),
            session: session
        )
        SponsorBlockRetryURLProtocol.configure(statusCodes: [503, 200])

        let segments = try await service.fetchSkipSegments(bvid: "BV-retry", cid: 11)

        XCTAssertEqual(segments.map(\.id), ["retry-segment"])
        XCTAssertEqual(SponsorBlockRetryURLProtocol.requestCount, 2)

        SponsorBlockRetryURLProtocol.configure(statusCodes: [404])
        let missingSegments = try await service.fetchSkipSegments(bvid: "BV-missing", cid: 22)

        XCTAssertTrue(missingSegments.isEmpty)
        XCTAssertEqual(SponsorBlockRetryURLProtocol.requestCount, 1)
    }

    func testViewedPOSTIsNotAutomaticallyReplayed() async throws {
        let session = makeRetrySession()
        let service = SponsorBlockService(
            baseURL: try XCTUnwrap(URL(string: "https://sponsor-block.test")),
            session: session
        )
        SponsorBlockRetryURLProtocol.configure(statusCodes: [503, 200])

        await service.reportViewed(uuid: "one-shot")

        XCTAssertEqual(SponsorBlockRetryURLProtocol.requestCount, 1)
        XCTAssertEqual(SponsorBlockRetryURLProtocol.requestMethods, ["POST"])
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

    private func makeRetrySession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SponsorBlockRetryURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private nonisolated final class SponsorBlockRetryURLProtocol: URLProtocol, @unchecked Sendable {
    private static let state = SponsorBlockRetryURLProtocolState()

    static var requestCount: Int { state.requestCount }
    static var requestMethods: [String] { state.requestMethods }

    static func configure(statusCodes: [Int]) {
        state.configure(statusCodes: statusCodes)
    }

    static func reset() {
        state.configure(statusCodes: [])
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "sponsor-block.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let statusCode = Self.state.beginRequest(method: request.httpMethod ?? "GET")
        let data: Data
        if statusCode == 200, request.httpMethod != "POST" {
            data = Data(
                "[{\"cid\":\"11\",\"category\":\"sponsor\",\"segment\":[2,8],\"UUID\":\"retry-segment\"}]".utf8
            )
        } else {
            data = Data("temporary".utf8)
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private nonisolated final class SponsorBlockRetryURLProtocolState: @unchecked Sendable {
    private let lock = NSLock()
    private var statusCodes = [Int]()
    private var recordedRequestMethods = [String]()

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequestMethods.count
    }

    var requestMethods: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequestMethods
    }

    func configure(statusCodes: [Int]) {
        lock.lock()
        self.statusCodes = statusCodes
        recordedRequestMethods = []
        lock.unlock()
    }

    func beginRequest(method: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        recordedRequestMethods.append(method)
        guard !statusCodes.isEmpty else { return 500 }
        return statusCodes.removeFirst()
    }
}
