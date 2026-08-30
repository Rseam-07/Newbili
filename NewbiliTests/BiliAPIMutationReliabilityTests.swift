import Foundation
import Testing
@testable import bili

@Suite(.serialized)
@MainActor
struct BiliAPIMutationReliabilityTests {
    @Test
    func `concurrent identical comments produce one non-idempotent request`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/v2/reply/add",
            responses: [.success],
            responseDelay: 0.08
        )

        async let first: Void = harness.api.submitComment(
            oid: "170001",
            type: 1,
            message: "避免重复发送"
        )
        async let second: Void = harness.api.submitComment(
            oid: "170001",
            type: 1,
            message: "避免重复发送"
        )
        _ = try await (first, second)

        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/v2/reply/add") == 1)
    }

    @Test
    func `failed comment is not replayed but an explicit retry is allowed`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/v2/reply/add",
            responses: [.serviceUnavailable, .success]
        )

        await #expect(throws: BiliAPIError.self) {
            try await harness.api.submitComment(
                oid: "170001",
                type: 1,
                message: "网络恢复后手动重试"
            )
        }
        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/v2/reply/add") == 1)

        try await harness.api.submitComment(
            oid: "170001",
            type: 1,
            message: "网络恢复后手动重试"
        )
        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/v2/reply/add") == 2)
    }

    @Test
    func `idempotent like retries a transient server failure once`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/web-interface/archive/like",
            responses: [.serviceUnavailable, .success]
        )

        try await harness.api.toggleVideoLike(aid: 170001, liked: true)

        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/web-interface/archive/like") == 2)
    }

    @Test
    func `concurrent identical coin submissions spend once`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/web-interface/coin/add",
            responses: [.success],
            responseDelay: 0.08
        )

        async let first: Void = harness.api.addVideoCoin(aid: 170001, multiply: 1)
        async let second: Void = harness.api.addVideoCoin(aid: 170001, multiply: 1)
        _ = try await (first, second)

        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/web-interface/coin/add") == 1)
    }

    @Test
    func `concurrent triple actions share one request and one result`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/web-interface/archive/like/triple",
            responses: [.success],
            responseDelay: 0.08
        )

        async let first = harness.api.tripleVideo(aid: 170001, bvid: "BV1mutation")
        async let second = harness.api.tripleVideo(aid: 170001, bvid: "BV1mutation")
        let results = try await (first, second)

        #expect(results.0 == results.1)
        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/web-interface/archive/like/triple") == 1)
    }

    @Test
    func `concurrent identical danmaku posts share one non-idempotent request`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/v2/dm/post",
            responses: [.success],
            responseDelay: 0.08
        )

        async let first = harness.api.postDanmaku(
            bvid: "BV1mutation",
            cid: 9001,
            progress: 12.345,
            text: "不要重复发送",
            mode: .scrolling,
            fontSize: 25,
            color: 0xFFFFFF
        )
        async let second = harness.api.postDanmaku(
            bvid: "BV1mutation",
            cid: 9001,
            progress: 12.345,
            text: "不要重复发送",
            mode: .scrolling,
            fontSize: 25,
            color: 0xFFFFFF
        )
        _ = try await (first, second)

        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/v2/dm/post") == 1)
    }

    @Test
    func `concurrent favorite folder changes submit once`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/v3/fav/resource/deal",
            responses: [.success],
            responseDelay: 0.08
        )

        async let first: Void = harness.api.setVideoFavorite(
            aid: 170001,
            addFolderIDs: [8, 3],
            removeFolderIDs: [5]
        )
        async let second: Void = harness.api.setVideoFavorite(
            aid: 170001,
            addFolderIDs: [3, 8],
            removeFolderIDs: [5]
        )
        _ = try await (first, second)

        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/v3/fav/resource/deal") == 1)
    }

    @Test
    func `concurrent identical danmaku reports submit once`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/dm/report/add",
            responses: [.success],
            responseDelay: 0.08
        )

        async let first: Void = harness.api.reportDanmaku(
            cid: 9001,
            dmid: 70001,
            reason: .other,
            content: "测试举报说明"
        )
        async let second: Void = harness.api.reportDanmaku(
            cid: 9001,
            dmid: 70001,
            reason: .other,
            content: "测试举报说明"
        )
        _ = try await (first, second)

        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/dm/report/add") == 1)
    }

    @Test
    func `failed triple is not replayed automatically and remains retryable`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/web-interface/archive/like/triple",
            responses: [.serviceUnavailable, .success]
        )

        await #expect(throws: BiliAPIError.self) {
            _ = try await harness.api.tripleVideo(aid: 170001, bvid: "BV1retry")
        }
        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/web-interface/archive/like/triple") == 1)

        _ = try await harness.api.tripleVideo(aid: 170001, bvid: "BV1retry")
        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/web-interface/archive/like/triple") == 2)
    }

    @Test
    func `concurrent identical follow mutations submit once across surfaces`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/relation/modify",
            responses: [.success],
            responseDelay: 0.08
        )

        async let videoDetail: Void = harness.api.setUploaderFollowing(
            mid: 2002,
            following: true
        )
        async let uploaderPage: Void = harness.api.setUploaderFollowing(
            mid: 2002,
            following: true
        )
        _ = try await (videoDetail, uploaderPage)

        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/relation/modify") == 1)
    }

    @Test
    func `failed follow mutation is not replayed and remains retryable`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        MutationReliabilityURLProtocol.configure(
            path: "/x/relation/modify",
            responses: [.serviceUnavailable, .success]
        )

        await #expect(throws: BiliAPIError.self) {
            try await harness.api.setUploaderFollowing(mid: 2002, following: true)
        }
        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/relation/modify") == 1)

        try await harness.api.setUploaderFollowing(mid: 2002, following: true)
        #expect(MutationReliabilityURLProtocol.requestCount(for: "/x/relation/modify") == 2)
    }

    @Test
    func `follow mutation identity uses stable account value state`() {
        let original = BiliAPIClient.uploaderFollowingMutationKey(
            accountMID: 1001,
            credentialVersion: 7,
            uploaderMID: 2002,
            following: true
        )
        let sameValue = BiliAPIClient.uploaderFollowingMutationKey(
            accountMID: 1001,
            credentialVersion: 7,
            uploaderMID: 2002,
            following: true
        )
        let newCredential = BiliAPIClient.uploaderFollowingMutationKey(
            accountMID: 1001,
            credentialVersion: 8,
            uploaderMID: 2002,
            following: true
        )
        let oppositeState = BiliAPIClient.uploaderFollowingMutationKey(
            accountMID: 1001,
            credentialVersion: 7,
            uploaderMID: 2002,
            following: false
        )

        #expect(original == sameValue)
        #expect(original != newCredential)
        #expect(original != oppositeState)
    }

    @Test
    func `mutation identities are normalized scoped and do not expose danmaku text`() {
        let secretText = "这段弹幕不应出现在去重键里"
        let original = BiliAPIClient.danmakuPostMutationKey(
            accountMID: 1001,
            credentialVersion: 7,
            bvid: "BV1privacy",
            cid: 9001,
            progressMilliseconds: 12_345,
            text: secretText,
            mode: .scrolling,
            fontSize: 25,
            color: 0xFFFFFF
        )
        let newCredential = BiliAPIClient.danmakuPostMutationKey(
            accountMID: 1001,
            credentialVersion: 8,
            bvid: "BV1privacy",
            cid: 9001,
            progressMilliseconds: 12_345,
            text: secretText,
            mode: .scrolling,
            fontSize: 25,
            color: 0xFFFFFF
        )
        let reportKey = BiliAPIClient.danmakuReportMutationKey(
            accountMID: 1001,
            credentialVersion: 7,
            cid: 9001,
            dmid: 70001,
            reason: .other,
            content: secretText
        )
        let firstFavorite = BiliAPIClient.videoFavoriteMutationKey(
            accountMID: 1001,
            credentialVersion: 7,
            aid: 170001,
            addFolderIDs: [8, 3],
            removeFolderIDs: [5]
        )
        let reorderedFavorite = BiliAPIClient.videoFavoriteMutationKey(
            accountMID: 1001,
            credentialVersion: 7,
            aid: 170001,
            addFolderIDs: [3, 8],
            removeFolderIDs: [5]
        )

        #expect(original.hasPrefix("danmaku-post:"))
        #expect(original.count == "danmaku-post:".count + 64)
        #expect(!original.contains(secretText))
        #expect(reportKey.count == "danmaku-report:".count + 64)
        #expect(!reportKey.contains(secretText))
        #expect(original != newCredential)
        #expect(firstFavorite == reorderedFavorite)
    }

    @Test
    func `deduplication state joins suppresses and releases failures`() throws {
        let key = "comment-key"
        let now = Date(timeIntervalSince1970: 1_000)
        var state = BiliNonIdempotentMutationDeduplicationState()

        let first = state.begin(key: key, now: now, successCooldown: 2)
        guard case .start(let firstToken) = first else {
            Issue.record("The first mutation should lead the request")
            return
        }
        #expect(state.begin(key: key, now: now, successCooldown: 2) == .join(firstToken))

        state.finish(key: key, token: firstToken, succeeded: true, now: now)
        #expect(
            state.begin(
                key: key,
                now: now.addingTimeInterval(1),
                successCooldown: 2
            ) == .suppressRecentSuccess
        )

        let afterCooldown = state.begin(
            key: key,
            now: now.addingTimeInterval(3),
            successCooldown: 2
        )
        guard case .start(let retryToken) = afterCooldown else {
            Issue.record("The key should reopen after the success cooldown")
            return
        }
        state.finish(
            key: key,
            token: retryToken,
            succeeded: false,
            now: now.addingTimeInterval(3)
        )
        guard case .start = state.begin(
            key: key,
            now: now.addingTimeInterval(3),
            successCooldown: 2
        ) else {
            Issue.record("A failure must allow an immediate explicit retry")
            return
        }
    }

    private func makeHarness() throws -> MutationReliabilityHarness {
        MutationReliabilityURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MutationReliabilityURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let keychain = KeychainStore(
            service: "cc.bili.tests.mutation-reliability.\(UUID().uuidString)"
        )
        let sessionStore = SessionStore(keychain: keychain)
        try sessionStore.saveLoginCookies(
            [
                "buvid3": "mutation-test-buvid",
                "DedeUserID": "1001",
                "SESSDATA": "mutation-test-session",
                "bili_jct": "mutation-test-csrf"
            ],
            credentialKind: .web
        )
        let defaultsName = "cc.bili.tests.mutation-reliability.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        let api = BiliAPIClient(
            session: session,
            sessionStore: sessionStore,
            libraryStore: LibraryStore(userDefaults: defaults),
            homeRecommendDiagnosticsStore: .shared
        )
        return MutationReliabilityHarness(
            api: api,
            session: session,
            sessionStore: sessionStore,
            defaults: defaults,
            defaultsName: defaultsName
        )
    }
}

@MainActor
private struct MutationReliabilityHarness {
    let api: BiliAPIClient
    let session: URLSession
    let sessionStore: SessionStore
    let defaults: UserDefaults
    let defaultsName: String

    func cleanup() {
        try? sessionStore.logout()
        defaults.removePersistentDomain(forName: defaultsName)
        session.invalidateAndCancel()
        MutationReliabilityURLProtocol.reset()
    }
}

private nonisolated final class MutationReliabilityURLProtocol: URLProtocol, @unchecked Sendable {
    enum Response: Sendable {
        case success
        case serviceUnavailable

        var statusCode: Int {
            switch self {
            case .success: 200
            case .serviceUnavailable: 503
            }
        }

        var body: Data {
            switch self {
            case .success:
                Data(#"{"code":0,"message":"0","data":{}}"#.utf8)
            case .serviceUnavailable:
                Data(#"{"code":-503,"message":"服务暂时不可用"}"#.utf8)
            }
        }
    }

    private static let state = MutationReliabilityURLProtocolState()

    static func configure(
        path: String,
        responses: [Response],
        responseDelay: TimeInterval = 0
    ) {
        state.configure(
            path: path,
            responses: responses,
            responseDelay: responseDelay
        )
    }

    static func requestCount(for path: String) -> Int {
        state.requestCount(for: path)
    }

    static func reset() {
        state.reset()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.contains("bilibili.com") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let planned = Self.state.nextResponse(for: url.path)
        if planned.delay > 0 {
            Thread.sleep(forTimeInterval: planned.delay)
        }
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: planned.response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: planned.response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private nonisolated final class MutationReliabilityURLProtocolState: @unchecked Sendable {
    struct PlannedResponse: Sendable {
        let response: MutationReliabilityURLProtocol.Response
        let delay: TimeInterval
    }

    private let lock = NSLock()
    private var responsesByPath: [String: [MutationReliabilityURLProtocol.Response]] = [:]
    private var responseDelaysByPath: [String: TimeInterval] = [:]
    private var requestCounts: [String: Int] = [:]

    func configure(
        path: String,
        responses: [MutationReliabilityURLProtocol.Response],
        responseDelay: TimeInterval
    ) {
        lock.lock()
        responsesByPath[path] = responses
        responseDelaysByPath[path] = max(0, responseDelay)
        requestCounts[path] = 0
        lock.unlock()
    }

    func nextResponse(for path: String) -> PlannedResponse {
        lock.lock()
        defer { lock.unlock() }
        requestCounts[path, default: 0] += 1
        let delay = responseDelaysByPath[path] ?? 0
        guard var responses = responsesByPath[path], !responses.isEmpty else {
            return PlannedResponse(response: .success, delay: delay)
        }
        let response = responses.removeFirst()
        responsesByPath[path] = responses
        return PlannedResponse(response: response, delay: delay)
    }

    func requestCount(for path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCounts[path, default: 0]
    }

    func reset() {
        lock.lock()
        responsesByPath.removeAll(keepingCapacity: false)
        responseDelaysByPath.removeAll(keepingCapacity: false)
        requestCounts.removeAll(keepingCapacity: false)
        lock.unlock()
    }
}
