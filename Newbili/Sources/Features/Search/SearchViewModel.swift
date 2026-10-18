import Foundation
import Combine
import SwiftUI

enum SearchSortOrder: String, CaseIterable, Identifiable, Hashable {
    case comprehensive
    case mostPlayed
    case newest
    case mostSaved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comprehensive:
            return "综合排序"
        case .mostPlayed:
            return "最多播放"
        case .newest:
            return "最新发布"
        case .mostSaved:
            return "最多收藏"
        }
    }

    var shortTitle: String {
        switch self {
        case .comprehensive:
            return "综合"
        case .mostPlayed:
            return "播放"
        case .newest:
            return "最新"
        case .mostSaved:
            return "收藏"
        }
    }

    var apiValue: String? {
        switch self {
        case .comprehensive:
            return nil
        case .mostPlayed:
            return "click"
        case .newest:
            return "pubdate"
        case .mostSaved:
            return "stow"
        }
    }
}

enum SearchScope: String, CaseIterable, Identifiable, Hashable {
    case comprehensive
    case video
    case bangumi
    case movie
    case user
    case article

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comprehensive:
            return "综合"
        case .video:
            return "视频"
        case .bangumi:
            return "番剧"
        case .movie:
            return "影视"
        case .user:
            return "UP主"
        case .article:
            return "专栏"
        }
    }

    var systemImage: String {
        switch self {
        case .comprehensive:
            return "magnifyingglass"
        case .video:
            return "play.rectangle"
        case .bangumi:
            return "play.tv"
        case .movie:
            return "film"
        case .user:
            return "person.crop.circle"
        case .article:
            return "doc.text"
        }
    }

    var supportsOrder: Bool {
        self == .comprehensive || self == .video
    }
}

enum SearchResultItem: Identifiable, Hashable {
    case video(VideoItem)
    case user(SearchUserItem)
    case bangumi(SearchMediaItem)
    case movie(SearchMediaItem)
    case article(SearchArticleItem)

    var id: String {
        switch self {
        case .video(let video):
            return "video-\(video.id)"
        case .user(let user):
            return "user-\(user.id)"
        case .bangumi(let media):
            return "bangumi-\(media.id)"
        case .movie(let media):
            return "movie-\(media.id)"
        case .article(let article):
            return "article-\(article.id)"
        }
    }
}

@MainActor
protocol NativeSearchServing {
    func fetchHotSearch() async throws -> [HotSearchItem]
    func fetchSearchSuggest(term: String) async throws -> [SearchSuggestItem]
    func searchVideos(keyword: String, page: Int, order: String?, filters: [String: String]) async throws -> [VideoItem]
    func searchUsers(keyword: String, page: Int) async throws -> [SearchUserItem]
    func searchBangumi(keyword: String, page: Int) async throws -> [SearchMediaItem]
    func searchMovies(keyword: String, page: Int) async throws -> [SearchMediaItem]
    func searchArticles(keyword: String, page: Int) async throws -> [SearchArticleItem]
}

extension BiliAPIClient: NativeSearchServing {}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedScope: SearchScope = .comprehensive
    @Published var selectedOrder: SearchSortOrder = .comprehensive
    @Published private(set) var videoFilters = SearchVideoFilters()
    @Published var hotSearches: [HotSearchItem] = []
    @Published var suggestions: [SearchSuggestItem] = []
    @Published var results: [SearchResultItem] = []
    @Published var state: LoadingState = .idle
    @Published var hotSearchState: LoadingState = .idle
    private(set) var hotSearchesRevision = 0
    private(set) var suggestionsRevision = 0
    private(set) var resultsRevision = 0

    private let api: any NativeSearchServing
    private let libraryStore: LibraryStore?
    private let debouncer = TaskDebouncer()
    private let suggestionDebounceDelay: Duration
    private var page = 1
    private var lastKeyword = ""
    private var videoFilterParameters: [String: String] = [:]
    private var hasMore = false
    private var requestRevision = 0
    private var searchTask: Task<[SearchResultItem], Error>?
    private var userTask: Task<[SearchUserItem], Never>?
    private var supplementaryTask: Task<Void, Never>?


    init(api: any NativeSearchServing, libraryStore: LibraryStore? = nil, suggestionDebounceDelay: Duration = .milliseconds(250)) {
        self.api = api
        self.libraryStore = libraryStore
        self.suggestionDebounceDelay = suggestionDebounceDelay
    }

    deinit {
        searchTask?.cancel()
        userTask?.cancel()
        supplementaryTask?.cancel()
    }

    private func invalidateRequests() {
        requestRevision &+= 1
        searchTask?.cancel()
        userTask?.cancel()
        supplementaryTask?.cancel()
        searchTask = nil
        userTask = nil
        supplementaryTask = nil
    }

    var showsDiscovery: Bool {
        results.isEmpty && lastKeyword.isEmpty
    }

    var showsSuggestions: Bool {
        showsDiscovery && libraryStore?.showsSearchSuggestions != false
            && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !suggestions.isEmpty
    }

    var paginationTriggerItem: SearchResultItem? {
        selectedScope == .comprehensive
            ? results.last(where: { if case .video = $0 { return true }; return false })
            : results.last
    }

    var canLoadMore: Bool { hasMore && !lastKeyword.isEmpty && !state.isLoading }

    var showsEmptyResults: Bool {
        results.isEmpty && !lastKeyword.isEmpty && state == .loaded
    }

    var searchPrompt: String {
        selectedScope == .comprehensive ? "搜索" : "搜索\(selectedScope.title)"
    }

    var emptyResultsTitle: String {
        selectedScope == .comprehensive ? "没有找到相关内容" : "没有找到\(selectedScope.title)"
    }

    func loadHotSearch() async {
        guard !hotSearchState.isLoading else { return }
        hotSearchState = .loading
        do {
            updateHotSearches(try await api.fetchHotSearch())
            hotSearchState = .loaded
        } catch {
            hotSearchState = .failed(error.localizedDescription)
        }
    }

    func queryChanged() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            debouncer.cancel()
            invalidateRequests()
            updateSuggestions([])
            updateResults([])
            lastKeyword = ""
            hasMore = false
            state = .idle
            return
        }
        if term != lastKeyword {
            invalidateRequests()
            updateResults([])
            lastKeyword = ""
            hasMore = false
            state = .idle
        }
        updateSuggestions([])
        guard libraryStore?.showsSearchSuggestions != false else {
            debouncer.cancel()
            return
        }
        debouncer.schedule(delay: suggestionDebounceDelay) { [weak self] in
            await self?.loadSuggestions(term: term)
        }
    }

    func clearQuery() {
        debouncer.cancel()
        invalidateRequests()
        query = ""
        updateSuggestions([])
        updateResults([])
        lastKeyword = ""
        hasMore = false
        state = .idle
    }

    func search(_ keyword: String? = nil) async {
        let term = (keyword ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        debouncer.cancel()
        invalidateRequests()
        let revision = requestRevision
        let scope = selectedScope
        let order = selectedOrder
        let filters = videoFilters.parameters()
        videoFilterParameters = filters
        query = term
        libraryStore?.recordSearchKeyword(term)
        page = 1
        lastKeyword = term
        hasMore = false
        updateSuggestions([])
        updateResults([])
        state = .loading
        let api = api
        let users: Task<[SearchUserItem], Never>?
        if scope == .comprehensive {
            users = Task { (try? await api.searchUsers(keyword: term, page: 1)) ?? [] }
        } else {
            users = nil
        }
        userTask = users
        let task = Task { try await self.fetchResults(keyword: term, page: 1, scope: scope, order: order, filters: filters) }
        searchTask = task
        do {
            let fetched = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel(); users?.cancel() }
            guard revision == requestRevision else { return }
            guard !Task.isCancelled, !task.isCancelled else {
                searchTask = nil
                users?.cancel()
                userTask = nil
                lastKeyword = ""
                state = .idle
                return
            }
            searchTask = nil
            updateResults(fetched)
            hasMore = !fetched.isEmpty
            state = .loaded
            if let users {
                supplementaryTask = Task { [weak self] in
                    let items = await users.value
                    guard let self, !Task.isCancelled, revision == self.requestRevision else { return }
                    // Optional uploader results never hold back playable results
                    // or move cards that the user has already started reading.
                    self.appendUnique(items.prefix(3).map(SearchResultItem.user))
                    self.userTask = nil
                    self.supplementaryTask = nil
                }
            }
        } catch {
            guard revision == requestRevision else { return }
            users?.cancel()
            searchTask = nil
            userTask = nil
            if error is CancellationError || Task.isCancelled {
                lastKeyword = ""
                state = .idle
            } else { state = .failed(error.localizedDescription) }
        }
    }

    func searchHotSearch(_ item: HotSearchItem) async {
        selectedScope = .comprehensive
        selectedOrder = .comprehensive
        await search(item.keyword)
    }

    func selectScope(_ scope: SearchScope, animation: Animation? = nil) async {
        guard selectedScope != scope else { return }
        if let animation {
            withAnimation(animation) {
                selectedScope = scope
            }
        } else {
            selectedScope = scope
        }
        guard !lastKeyword.isEmpty else { return }
        await search(lastKeyword)
    }

    func selectOrder(_ order: SearchSortOrder) async {
        guard selectedOrder != order else { return }
        selectedOrder = order
        guard selectedScope.supportsOrder, !lastKeyword.isEmpty else { return }
        await search(lastKeyword)
    }

    func selectVideoFilters(_ filters: SearchVideoFilters) async {
        guard videoFilters != filters else { return }
        videoFilters = filters
        guard selectedScope.supportsOrder, !lastKeyword.isEmpty else { return }
        await search(lastKeyword)
    }

    func loadMoreIfNeeded(current item: SearchResultItem?) async {
        // Supplemental uploader cards must not trigger another video page.
        guard let item, paginationTriggerItem?.id == item.id, !state.isLoading,
              !lastKeyword.isEmpty, hasMore else { return }
        let revision = requestRevision
        let nextPage = page + 1
        let term = lastKeyword
        let scope = selectedScope
        let order = selectedOrder
        let filters = videoFilterParameters
        state = .loading
        let task = Task { try await self.fetchResults(keyword: term, page: nextPage, scope: scope, order: order, filters: filters) }
        searchTask = task
        do {
            let more = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            guard revision == requestRevision else { return }
            guard !Task.isCancelled, !task.isCancelled else {
                searchTask = nil
                state = .loaded
                return
            }
            searchTask = nil
            page = nextPage
            if more.isEmpty { hasMore = false }
            appendUnique(more)
            state = .loaded
        } catch {
            guard revision == requestRevision else { return }
            searchTask = nil
            state = error is CancellationError || Task.isCancelled ? .loaded : .failed(error.localizedDescription)
        }
    }

    private func fetchResults(keyword: String, page: Int, scope: SearchScope, order: SearchSortOrder, filters: [String: String]) async throws -> [SearchResultItem] {
        switch scope {
        case .comprehensive, .video:
            return try await api.searchVideos(keyword: keyword, page: page, order: order.apiValue, filters: filters).map(SearchResultItem.video)
        case .bangumi:
            return try await api.searchBangumi(keyword: keyword, page: page).map(SearchResultItem.bangumi)
        case .movie:
            return try await api.searchMovies(keyword: keyword, page: page).map(SearchResultItem.movie)
        case .user:
            return try await api.searchUsers(keyword: keyword, page: page).map(SearchResultItem.user)
        case .article:
            return try await api.searchArticles(keyword: keyword, page: page).map(SearchResultItem.article)
        }
    }

    private func loadSuggestions(term: String) async {
        do {
            let items = try await api.fetchSearchSuggest(term: term)
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == term,
                  lastKeyword != term, libraryStore?.showsSearchSuggestions != false else { return }
            var seen = Set<String>()
            updateSuggestions(items.filter { !$0.value.isEmpty && seen.insert($0.value).inserted })
        } catch {
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == term else { return }
            updateSuggestions([])
        }
    }

    private func appendUnique(_ more: [SearchResultItem]) {
        let existing = Set(results.map(\.id))
        var seen = existing
        let uniqueItems = more.filter { seen.insert($0.id).inserted }
        guard !uniqueItems.isEmpty else { return }
        results.append(contentsOf: uniqueItems)
        resultsRevision &+= 1
    }

    private func updateHotSearches(_ values: [HotSearchItem]) {
        guard hotSearches != values else { return }
        hotSearches = values
        hotSearchesRevision &+= 1
    }

    private func updateSuggestions(_ values: [SearchSuggestItem]) {
        guard suggestions != values else { return }
        suggestions = values
        suggestionsRevision &+= 1
    }

    private func updateResults(_ values: [SearchResultItem]) {
        guard results != values else { return }
        results = values
        resultsRevision &+= 1
    }
}
