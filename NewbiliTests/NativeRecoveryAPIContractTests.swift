import Foundation
import Testing
@testable import bili

@Suite(.serialized)
@MainActor
struct NativeRecoveryAPIContractTests {
    @Test func suggestionsUseTheSuggestionHostAndDecodeStringReferences() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        RecoveryAPIURLProtocol.state.configure(#"{"code":0,"result":{"tag":[{"value":"Flutter 入门","ref":"3"},{"value":"Flutter","ref":"optional"}]}}"#)
        let items = try await harness.api.fetchSearchSuggest(term: "Flutter-contract")
        #expect(items.map(\.value) == ["Flutter 入门", "Flutter"])
        #expect(items.map(\.ref) == [3, nil])
        let request = try #require(RecoveryAPIURLProtocol.state.urls.last)
        #expect(request.host == "s.search.bilibili.com")
        #expect(request.path == "/main/suggest")
        #expect(query(request)["term"] == "Flutter-contract")
    }

    @Test func videoFilterParametersReachTheSignedRequestWithoutOverridingKeywordOrPage() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        RecoveryAPIURLProtocol.state.configure(#"{"code":0,"data":{"result":[]}}"#)
        _ = try await harness.api.searchVideos(keyword: "filters-contract", page: 2, order: "pubdate",
                                               filters: ["duration": "3", "tids": "188", "pubtime_begin_s": "1700000000",
                                                         "pubtime_end_s": "1700604800", "keyword": "wrong", "page": "99"])
        let request = try #require(RecoveryAPIURLProtocol.state.urls.last { $0.path.hasSuffix("search/type") })
        let values = query(request)
        #expect(values["keyword"] == "filters-contract")
        #expect(values["page"] == "2")
        #expect(values["duration"] == "3")
        #expect(values["tids"] == "188")
        #expect(values["pubtime_begin_s"] == "1700000000")
        #expect(values["pubtime_end_s"] == "1700604800")
        #expect(values["w_rid"]?.isEmpty == false)
    }

    @Test func successfulReplyCodeWithoutDataIsAnErrorRatherThanAnEmptyThread() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        RecoveryAPIURLProtocol.state.configure(#"{"code":0}"#)
        do {
            _ = try await harness.api.fetchCommentReplies(oid: "9001", type: 1, root: 100)
            Issue.record("Missing reply data must fail")
        } catch {
            #expect(error is BiliAPIError)
        }
    }

    @Test func serverReplyPageMetadataSurvivesTheAPIAndUsesRequestedRoot() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        RecoveryAPIURLProtocol.state.configure(#"{"code":0,"data":{"replies":[{"rpid":101}],"page":{"count":"41","num":"2","size":"20"}}}"#)
        let page = try await harness.api.fetchCommentReplies(oid: "9002", type: 33, root: 200, page: 2)
        #expect(page.page?.count == 41)
        #expect(page.hasMoreThreadReplies(requestedPage: 2, rawReplyCount: 1, fallbackTotal: 1))
        let url = try #require(RecoveryAPIURLProtocol.state.urls.last)
        #expect(query(url)["root"] == "200")
        #expect(query(url)["pn"] == "2")
        #expect(query(url)["type"] == "33")
    }

    private func query(_ url: URL) -> [String: String] {
        Dictionary((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") },
                   uniquingKeysWith: { _, newest in newest })
    }

    private func makeHarness() -> RecoveryAPIHarness {
        let name = "cc.bili.tests.recovery-api.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecoveryAPIURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let library = LibraryStore(userDefaults: defaults)
        let account = SessionStore(keychain: KeychainStore(service: name))
        let api = BiliAPIClient(session: session, sessionStore: account, libraryStore: library, homeRecommendDiagnosticsStore: .shared)
        return RecoveryAPIHarness(api: api, session: session, defaults: defaults, name: name)
    }
}

@MainActor
private struct RecoveryAPIHarness {
    let api: BiliAPIClient
    let session: URLSession
    let defaults: UserDefaults
    let name: String
    func cleanup() {
        session.invalidateAndCancel()
        defaults.removePersistentDomain(forName: name)
    }
}

private nonisolated final class RecoveryAPIURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = RecoveryAPIProtocolState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let data = Self.state.response(for: url)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private nonisolated final class RecoveryAPIProtocolState: @unchecked Sendable {
    private let lock = NSLock()
    private var responseJSON = "{}"
    private var requests: [URL] = []
    var urls: [URL] { lock.withLock { requests } }
    func configure(_ json: String) { lock.withLock { responseJSON = json; requests = [] } }
    func response(for url: URL) -> Data {
        lock.withLock {
            requests.append(url)
            if url.path == "/x/web-interface/nav" {
                return Data(#"{"code":0,"data":{"wbi_img":{"img_url":"https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png","sub_url":"https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png"}}}"#.utf8)
            }
            return Data(responseJSON.utf8)
        }
    }
}
