import Foundation
import Combine
import Testing
@testable import bili

@Suite(.serialized)
@MainActor
struct NativeSearchReliabilityTests {
    @Test func changingVideoFiltersRejectsAnOldPageAndKeepsFiltersForPagination() async {
        let service = ControlledNativeSearch()
        let model = SearchViewModel(api: service)
        model.selectedScope = .video
        let first = Task { await model.search("filters") }
        await service.started("filters/1")
        service.finish("filters/1", videos: [RootTabView.seedVideo(bvid: "BV-before")])
        await first.value
        let oldPage = Task { await model.loadMoreIfNeeded(current: model.results.last) }
        await service.started("filters/2")
        let filters = SearchVideoFilters(duration: .tenToThirtyMinutes, zone: .technology, published: .week)
        let changed = Task { await model.selectVideoFilters(filters) }
        await service.started("filters/1")
        service.finish("filters/1", videos: [RootTabView.seedVideo(bvid: "BV-filtered")])
        await changed.value
        service.finish("filters/2", videos: [RootTabView.seedVideo(bvid: "BV-obsolete")])
        await oldPage.value
        #expect(model.results.map(\.id) == ["video-BV-filtered"])
        let more = Task { await model.loadMoreIfNeeded(current: model.results.last) }
        await service.started("filters/2")
        service.finish("filters/2", videos: [])
        await more.value
        #expect(service.pages == [1, 2, 1, 2])
        #expect(service.filterParameters[2] == service.filterParameters[3])
        #expect(service.filterParameters[2]["duration"] == "2")
        #expect(service.filterParameters[2]["tids"] == "188")
    }

    @Test func videoFilterDateRangeUsesSecondsAndCanResetCompletely() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let filters = SearchVideoFilters(duration: .overSixtyMinutes, zone: .music, published: .week)
        #expect(filters.parameters(now: now) == ["duration": "4", "tids": "3",
                                               "pubtime_begin_s": "1799395200", "pubtime_end_s": "1800000000"])
        #expect(SearchVideoFilters().parameters(now: now).isEmpty)
        #expect(!SearchVideoFilters().isActive)
    }

    @Test func replacedRequestCannotOverwriteNewResults() async {
        let service = ControlledNativeSearch()
        let model = SearchViewModel(api: service)
        model.selectedScope = .video
        let old = Task { await model.search("old") }
        await service.started("old/1")
        let current = Task { await model.search("new") }
        await service.started("new/1")
        service.finish("new/1", videos: [RootTabView.seedVideo(bvid: "BV-new")])
        await current.value
        service.finish("old/1", videos: [RootTabView.seedVideo(bvid: "BV-old")])
        await old.value
        #expect(model.results.map(\.id) == ["video-BV-new"])
        #expect(model.state == .loaded)
    }

    @Test func clearQueryRejectsRequestThatIgnoresCancellation() async {
        let service = ControlledNativeSearch()
        let model = SearchViewModel(api: service)
        model.selectedScope = .video
        let request = Task { await model.search("draft") }
        await service.started("draft/1")
        model.clearQuery()
        service.finish("draft/1", videos: [RootTabView.seedVideo(bvid: "BV-stale")])
        await request.value
        #expect(model.query.isEmpty)
        #expect(model.results.isEmpty)
        #expect(model.state == .idle)
    }

    @Test func primaryResultsDoNotWaitForOptionalUploaderSearch() async {
        let service = ControlledNativeSearch()
        service.holdUploaders = true
        let model = SearchViewModel(api: service)
        let request = Task { await model.search("swift") }
        await service.started("swift/1")
        await service.started("users")
        service.finish("swift/1", videos: [RootTabView.seedVideo(bvid: "BV-playable")])
        await request.value
        #expect(model.results.map(\.id) == ["video-BV-playable"])
        #expect(model.state == .loaded)
        service.finishUsers()
        await Task.yield()
    }

    @Test func failedPaginationRetriesTheSamePageAndDeduplicatesResponse() async {
        let service = ControlledNativeSearch()
        let model = SearchViewModel(api: service)
        model.selectedScope = .video
        let first = Task { await model.search("page") }
        await service.started("page/1")
        service.finish("page/1", videos: [RootTabView.seedVideo(bvid: "BV-one")])
        await first.value
        let retryItem = model.results.last
        let failed = Task { await model.loadMoreIfNeeded(current: retryItem) }
        await service.started("page/2")
        service.fail("page/2")
        await failed.value
        let retry = Task { await model.loadMoreIfNeeded(current: retryItem) }
        await service.started("page/2")
        service.finish("page/2", videos: [RootTabView.seedVideo(bvid: "BV-one"), RootTabView.seedVideo(bvid: "BV-two"), RootTabView.seedVideo(bvid: "BV-two")])
        await retry.value
        #expect(model.results.map(\.id) == ["video-BV-one", "video-BV-two"])
        #expect(service.pages == [1, 2, 2])
    }

    @Test func articleScopeUsesTheExistingArticleEndpoint() async {
        let service = ControlledNativeSearch()
        let model = SearchViewModel(api: service)
        model.selectedScope = .article
        await model.search("专栏")
        #expect(service.articleQueries == ["专栏"])
        #expect(model.state == .loaded)
        #expect(SearchScope.article.systemImage == "doc.text")
    }

    @Test func optionalUsersDoNotBlockComprehensivePagination() async throws {
        let service = ControlledNativeSearch()
        service.holdUploaders = true
        let model = SearchViewModel(api: service)
        let request = Task { await model.search("mixed") }
        await service.started("mixed/1")
        await service.started("users")
        service.finish("mixed/1", videos: [RootTabView.seedVideo(bvid: "BV-first")])
        await request.value
        let user = try JSONDecoder().decode(SearchUserItem.self, from: Data(#"{"mid":42,"uname":"UP"}"#.utf8))
        let appended = Task {
            for await results in model.$results.values {
                if results.contains(where: { $0.id == "user-42" }) { break }
            }
        }
        service.finishUsers([user])
        await appended.value
        #expect(model.results.last?.id == "user-42")
        #expect(model.paginationTriggerItem?.id == "video-BV-first")
        let more = Task { await model.loadMoreIfNeeded(current: model.paginationTriggerItem) }
        await service.started("mixed/2")
        service.finish("mixed/2", videos: [RootTabView.seedVideo(bvid: "BV-second")])
        await more.value
        #expect(model.results.contains(where: { $0.id == "video-BV-second" }))
    }

    @Test func staleSuggestionsCannotReplaceTheCurrentQuery() async {
        let service = ControlledNativeSearch()
        service.holdSuggestions = true
        let model = SearchViewModel(api: service, suggestionDebounceDelay: .zero)
        model.query = "old"
        model.queryChanged()
        await service.started("suggest/old")
        model.query = "new"
        model.queryChanged()
        await service.started("suggest/new")
        let updated = Task {
            for await suggestions in model.$suggestions.values {
                if suggestions.first?.value == "new suggestion" { break }
            }
        }
        service.finishSuggestions("new", values: [SearchSuggestItem(value: "new suggestion", ref: nil)])
        await updated.value
        service.finishSuggestions("old", values: [SearchSuggestItem(value: "stale suggestion", ref: nil)])
        await Task.yield()
        #expect(model.suggestions.map(\.value) == ["new suggestion"])
    }

    @Test func cancellingThePageTaskDoesNotLeaveSearchPermanentlyLoading() async {
        let service = ControlledNativeSearch()
        let model = SearchViewModel(api: service)
        model.selectedScope = .video
        let request = Task { await model.search("cancelled") }
        await service.started("cancelled/1")
        request.cancel()
        service.finish("cancelled/1", videos: [RootTabView.seedVideo(bvid: "BV-cancelled")])
        await request.value
        #expect(model.state == .idle)
        #expect(model.results.isEmpty)
        #expect(model.showsDiscovery)
    }

    @Test func cancelledPaginationKeepsThePageRetryable() async {
        let service = ControlledNativeSearch()
        let model = SearchViewModel(api: service)
        model.selectedScope = .video
        let first = Task { await model.search("cancel-page") }
        await service.started("cancel-page/1")
        service.finish("cancel-page/1", videos: [RootTabView.seedVideo(bvid: "BV-first")])
        await first.value
        let more = Task { await model.loadMoreIfNeeded(current: model.paginationTriggerItem) }
        await service.started("cancel-page/2")
        more.cancel()
        service.finish("cancel-page/2", videos: [RootTabView.seedVideo(bvid: "BV-discard")])
        await more.value
        #expect(model.state == .loaded)
        #expect(model.canLoadMore)
        #expect(model.results.map(\.id) == ["video-BV-first"])
    }
}

@MainActor
private final class ControlledNativeSearch: NativeSearchServing {
    var holdUploaders = false
    var holdSuggestions = false
    var pages = [Int]()
    var filterParameters: [[String: String]] = []
    var articleQueries = [String]()
    private var pending = [String: CheckedContinuation<[VideoItem], Error>]()
    private var pendingUsers: CheckedContinuation<[SearchUserItem], Never>?
    private var pendingSuggestions = [String: CheckedContinuation<[SearchSuggestItem], Error>]()
    private var waiters = [String: CheckedContinuation<Void, Never>]()

    func started(_ key: String) async {
        if pending[key] != nil || pendingSuggestions[key] != nil || key == "users" && pendingUsers != nil { return }
        await withCheckedContinuation { waiters[key] = $0 }
    }
    func finish(_ key: String, videos: [VideoItem]) { pending.removeValue(forKey: key)?.resume(returning: videos) }
    func fail(_ key: String) { pending.removeValue(forKey: key)?.resume(throwing: BiliAPIError.emptyData) }
    func finishUsers(_ users: [SearchUserItem] = []) { pendingUsers?.resume(returning: users); pendingUsers = nil }
    func finishSuggestions(_ keyword: String, values: [SearchSuggestItem]) {
        pendingSuggestions.removeValue(forKey: "suggest/\(keyword)")?.resume(returning: values)
    }
    func fetchHotSearch() async throws -> [HotSearchItem] { [] }
    func fetchSearchSuggest(term: String) async throws -> [SearchSuggestItem] {
        guard holdSuggestions else { return [] }
        return try await withCheckedThrowingContinuation {
            let key = "suggest/\(term)"
            pendingSuggestions[key] = $0
            waiters.removeValue(forKey: key)?.resume()
        }
    }
    func searchVideos(keyword: String, page: Int, order: String?, filters: [String: String]) async throws -> [VideoItem] {
        pages.append(page)
        filterParameters.append(filters)
        return try await withCheckedThrowingContinuation {
            let key = "\(keyword)/\(page)"
            pending[key] = $0
            waiters.removeValue(forKey: key)?.resume()
        }
    }
    func searchUsers(keyword: String, page: Int) async throws -> [SearchUserItem] {
        guard holdUploaders else { return [] }
        return await withCheckedContinuation {
            pendingUsers = $0
            waiters.removeValue(forKey: "users")?.resume()
        }
    }
    func searchBangumi(keyword: String, page: Int) async throws -> [SearchMediaItem] { [] }
    func searchMovies(keyword: String, page: Int) async throws -> [SearchMediaItem] { [] }
    func searchArticles(keyword: String, page: Int) async throws -> [SearchArticleItem] { articleQueries.append(keyword); return [] }
}
