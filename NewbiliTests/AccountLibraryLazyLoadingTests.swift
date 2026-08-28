import Foundation
import Testing
@testable import bili

@MainActor
@Suite(.serialized)
struct AccountLibraryLazyLoadingTests {
    @Test
    func `profile refresh never prefetches unopened libraries`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let viewModel = MineViewModel(
            api: harness.api,
            sessionStore: harness.sessionStore,
            navUserLoader: {
                NavUserInfo(
                    isLogin: true,
                    face: nil,
                    uname: "按需加载账号",
                    mid: 1001,
                    wbiImg: nil
                )
            }
        )

        await viewModel.refreshUser()

        #expect(AccountLibraryURLProtocol.totalRequestCount == 0)
        #expect(viewModel.historyState == .idle)
        #expect(viewModel.favoriteState == .idle)
        #expect(viewModel.watchLaterState == .idle)
    }

    @Test
    func `top level libraries request an empty first page only once`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let viewModel = MineViewModel(api: harness.api, sessionStore: harness.sessionStore)

        await loadTwice(.history, in: viewModel)
        await loadTwice(.favorites, in: viewModel)
        await loadTwice(
            .watchLater(filter: .all, keyword: "", sortOrder: .newest),
            in: viewModel
        )

        #expect(AccountLibraryURLProtocol.requestCount(for: "/x/web-interface/history/cursor") == 1)
        #expect(AccountLibraryURLProtocol.requestCount(for: "/x/v3/fav/folder/created/list-all") == 1)
        #expect(AccountLibraryURLProtocol.requestCount(for: "/x/v3/fav/resource/list") == 0)
        #expect(AccountLibraryURLProtocol.requestCount(for: "/x/v2/history/toview/web") == 1)
        #expect(viewModel.historyState == .loaded)
        #expect(viewModel.favoriteState == .loaded)
        #expect(viewModel.favoriteFolders.map(\.id) == [11])
        #expect(viewModel.watchLaterState == .loaded)
    }

    @Test
    func `favorite folder page requests its first page only once`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let viewModel = MineViewModel(api: harness.api, sessionStore: harness.sessionStore)

        await loadTwice(.favoriteFolder(id: 11), in: viewModel)

        #expect(AccountLibraryURLProtocol.requestCount(for: "/x/v3/fav/resource/list") == 1)
        #expect(viewModel.favoriteFolderEntryStates[11] == .loaded)
    }

    @Test
    func `watch later caches only the exact normalized query`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let viewModel = MineViewModel(api: harness.api, sessionStore: harness.sessionStore)
        let defaultQuery = AccountLibraryLoadRequest.watchLater(
            filter: .all,
            keyword: "",
            sortOrder: .newest
        )
        let filteredQuery = AccountLibraryLoadRequest.watchLater(
            filter: .unfinished,
            keyword: " 旧筛选 ",
            sortOrder: .oldest
        )
        let normalizedFilteredQuery = AccountLibraryLoadRequest.watchLater(
            filter: .unfinished,
            keyword: "旧筛选",
            sortOrder: .oldest
        )

        await loadTwice(defaultQuery, in: viewModel)
        await loadTwice(filteredQuery, in: viewModel)
        await loadTwice(normalizedFilteredQuery, in: viewModel)
        await loadTwice(defaultQuery, in: viewModel)

        #expect(AccountLibraryURLProtocol.requestCount(for: "/x/v2/history/toview/web") == 3)
        #expect(viewModel.watchLaterState == .loaded)
    }

    @Test
    func `failed watch later refresh keeps results for the same query`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        AccountLibraryURLProtocol.setWatchLaterResponses([
            Self.watchLaterSuccessJSON,
            Self.watchLaterFailureJSON
        ])
        let viewModel = MineViewModel(api: harness.api, sessionStore: harness.sessionStore)
        let request = AccountLibraryLoadRequest.watchLater(
            filter: .all,
            keyword: "",
            sortOrder: .newest
        )

        await viewModel.loadAccountLibrary(request)
        await viewModel.loadAccountLibrary(request, policy: .reload)

        #expect(viewModel.watchLaterEntries.map(\.title) == ["可保留的旧结果"])
        guard case .failed = viewModel.watchLaterState else {
            Issue.record("同查询刷新失败后应显示失败状态")
            return
        }
    }

    @Test
    func `failed different watch later query never shows stale results`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        AccountLibraryURLProtocol.setWatchLaterResponses([
            Self.watchLaterSuccessJSON,
            Self.watchLaterFailureJSON
        ])
        let viewModel = MineViewModel(api: harness.api, sessionStore: harness.sessionStore)

        await viewModel.loadAccountLibrary(
            .watchLater(filter: .all, keyword: "", sortOrder: .newest)
        )
        await viewModel.loadAccountLibrary(
            .watchLater(filter: .unfinished, keyword: "新查询", sortOrder: .oldest)
        )

        #expect(viewModel.watchLaterEntries.isEmpty)
        #expect(viewModel.watchLaterTotalCount == 0)
        guard case .failed = viewModel.watchLaterState else {
            Issue.record("新查询失败后应显示失败状态")
            return
        }
    }

    @Test
    func `credential invalidation clears without prefetch and permits one new load`() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let viewModel = MineViewModel(api: harness.api, sessionStore: harness.sessionStore)

        await loadTwice(.history, in: viewModel)
        viewModel.invalidateAccountLibraries([.history])

        #expect(viewModel.historyState == .idle)
        #expect(AccountLibraryURLProtocol.requestCount(for: "/x/web-interface/history/cursor") == 1)

        await loadTwice(.history, in: viewModel)

        #expect(AccountLibraryURLProtocol.requestCount(for: "/x/web-interface/history/cursor") == 2)
        #expect(viewModel.historyState == .loaded)
    }

    private func loadTwice(
        _ request: AccountLibraryLoadRequest,
        in viewModel: MineViewModel
    ) async {
        async let first: Void = viewModel.loadAccountLibrary(request)
        async let second: Void = viewModel.loadAccountLibrary(request)
        _ = await (first, second)
        await viewModel.loadAccountLibrary(request)
    }

    private func makeHarness() throws -> AccountLibraryTestHarness {
        AccountLibraryURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountLibraryURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let keychain = KeychainStore(
            service: "cc.bili.tests.account-library-lazy.\(UUID().uuidString)"
        )
        let sessionStore = SessionStore(keychain: keychain)
        try sessionStore.saveLoginCookies(
            [
                "buvid3": "lazy-loading-buvid",
                "DedeUserID": "1001",
                "SESSDATA": "lazy-loading-session",
                "bili_jct": "lazy-loading-csrf"
            ],
            credentialKind: .web
        )
        let defaultsName = "cc.bili.tests.account-library-lazy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        let libraryStore = LibraryStore(userDefaults: defaults)
        let api = BiliAPIClient(
            session: session,
            sessionStore: sessionStore,
            libraryStore: libraryStore,
            homeRecommendDiagnosticsStore: .shared
        )
        return AccountLibraryTestHarness(
            api: api,
            session: session,
            sessionStore: sessionStore,
            defaults: defaults,
            defaultsName: defaultsName
        )
    }

    private static let watchLaterSuccessJSON = #"{"code":0,"data":{"list":[{"bvid":"BV1xx411c7mD","aid":170001,"title":"可保留的旧结果"}],"count":1}}"#
    private static let watchLaterFailureJSON = #"{"code":-400,"message":"筛选请求失败"}"#
}

@MainActor
private struct AccountLibraryTestHarness {
    let api: BiliAPIClient
    let session: URLSession
    let sessionStore: SessionStore
    let defaults: UserDefaults
    let defaultsName: String

    func cleanup() {
        try? sessionStore.logout()
        defaults.removePersistentDomain(forName: defaultsName)
        session.invalidateAndCancel()
        AccountLibraryURLProtocol.reset()
    }
}

private nonisolated final class AccountLibraryURLProtocol: URLProtocol, @unchecked Sendable {
    private static let state = AccountLibraryURLProtocolState()

    static var totalRequestCount: Int {
        state.totalRequestCount
    }

    static func requestCount(for path: String) -> Int {
        state.requestCount(for: path)
    }

    static func reset() {
        state.reset()
    }

    static func setWatchLaterResponses(_ responses: [String]) {
        state.setWatchLaterResponses(responses)
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
        let data = Self.state.responseData(for: url.path)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private nonisolated final class AccountLibraryURLProtocolState: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var watchLaterResponses: [Data] = []

    var totalRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return counts.values.reduce(0, +)
    }

    func requestCount(for path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[path, default: 0]
    }

    func reset() {
        lock.lock()
        counts = [:]
        watchLaterResponses = []
        lock.unlock()
    }

    func setWatchLaterResponses(_ responses: [String]) {
        lock.lock()
        watchLaterResponses = responses.map { Data($0.utf8) }
        lock.unlock()
    }

    func responseData(for path: String) -> Data {
        lock.lock()
        counts[path, default: 0] += 1
        let queuedWatchLaterResponse: Data?
        if path == "/x/v2/history/toview/web", !watchLaterResponses.isEmpty {
            queuedWatchLaterResponse = watchLaterResponses.removeFirst()
        } else {
            queuedWatchLaterResponse = nil
        }
        lock.unlock()

        if let queuedWatchLaterResponse {
            return queuedWatchLaterResponse
        }

        let json: String
        switch path {
        case "/x/web-interface/nav":
            json = #"{"code":0,"data":{"isLogin":true,"mid":1001,"wbi_img":{"img_url":"https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png","sub_url":"https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png"}}}"#
        case "/x/v3/fav/folder/created/list-all":
            json = #"{"code":0,"data":{"list":[{"id":11,"title":"默认收藏夹","media_count":0}]}}"#
        case "/x/web-interface/history/cursor":
            json = #"{"code":0,"data":{"list":[],"cursor":{"max":0,"view_at":0}}}"#
        case "/x/v2/history/toview/web":
            json = #"{"code":0,"data":{"list":[],"count":0}}"#
        case "/x/v3/fav/resource/list":
            json = #"{"code":0,"data":{"medias":[],"has_more":false}}"#
        default:
            json = #"{"code":0,"data":{}}"#
        }
        return Data(json.utf8)
    }
}
