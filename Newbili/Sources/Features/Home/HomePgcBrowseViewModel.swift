import Combine
import Foundation

@MainActor
protocol HomePgcServing {
    func fetchPgcBrowse(kind: HomePgcKind, page: Int, filters: [String: String]?) async throws -> PgcBrowsePage
    func fetchPgcIndexConditions(kind: HomePgcKind) async throws -> PgcIndexConditions
    func fetchPgcTimeline(types: Int) async throws -> [PgcTimelineDay]
}

extension BiliAPIClient: HomePgcServing {}

@MainActor
final class HomePgcBrowseViewModel: ObservableObject {
    let kind: HomePgcKind
    @Published private(set) var items: [PgcBrowseItem] = []
    @Published private(set) var timeline: [PgcTimelineDay] = []
    @Published private(set) var state: LoadingState = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreError: String?
    @Published private(set) var total: Int?
    @Published private(set) var conditions: PgcIndexConditions?
    @Published private(set) var conditionState: LoadingState = .idle
    @Published private(set) var timelineState: LoadingState = .idle
    @Published private(set) var selectedFilters = [String: String]()

    private var page = 1
    private var hasNext = true
    private var usesFilters = false
    private var requestRevision = 0
    private var pageTask: Task<PgcBrowsePage, Error>?
    private var conditionTask: Task<Void, Never>?
    private var timelineTask: Task<Void, Never>?

    init(kind: HomePgcKind) { self.kind = kind }

    deinit { pageTask?.cancel(); conditionTask?.cancel(); timelineTask?.cancel() }

    var canLoadMore: Bool { hasNext && !state.isLoading && !isLoadingMore && !items.isEmpty }
    var hasActiveFilters: Bool { usesFilters && selectedFilters != conditions?.defaultSelection }

    func loadInitial(api: any HomePgcServing) async {
        guard items.isEmpty, !state.isLoading else { return }
        loadConditions(api: api)
        loadTimeline(api: api)
        await refresh(api: api)
    }

    func refresh(api: any HomePgcServing) async {
        requestRevision &+= 1
        let revision = requestRevision
        pageTask?.cancel()
        isLoadingMore = false
        loadMoreError = nil
        state = .loading
        let filters = usesFilters ? selectedFilters : nil
        let kind = kind
        let task = Task { try await api.fetchPgcBrowse(kind: kind, page: 1, filters: filters) }
        pageTask = task
        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            guard revision == requestRevision else { return }
            guard !Task.isCancelled, !task.isCancelled else {
                pageTask = nil
                state = items.isEmpty ? .idle : .loaded
                return
            }
            var seen = Set<Int>()
            items = result.list.filter { $0.seasonID > 0 && seen.insert($0.id).inserted }
            page = 1
            hasNext = result.hasNext && !items.isEmpty
            total = result.total
            state = .loaded
            pageTask = nil
        } catch {
            guard revision == requestRevision else { return }
            pageTask = nil
            state = error is CancellationError || Task.isCancelled ? .idle : .failed(error.localizedDescription)
        }
    }

    func loadMore(api: any HomePgcServing) async {
        guard canLoadMore else { return }
        let revision = requestRevision
        let nextPage = page + 1
        let filters = usesFilters ? selectedFilters : nil
        let kind = kind
        isLoadingMore = true
        loadMoreError = nil
        let task = Task { try await api.fetchPgcBrowse(kind: kind, page: nextPage, filters: filters) }
        pageTask = task
        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            guard revision == requestRevision else { return }
            guard !Task.isCancelled, !task.isCancelled else {
                pageTask = nil
                isLoadingMore = false
                return
            }
            var seen = Set(items.map(\.id))
            let valid = result.list.filter { $0.seasonID > 0 }
            items.append(contentsOf: valid.filter { seen.insert($0.id).inserted })
            page = nextPage
            hasNext = result.hasNext && !valid.isEmpty
            total = result.total ?? total
            loadMoreError = nil
            isLoadingMore = false
            pageTask = nil
        } catch {
            guard revision == requestRevision else { return }
            isLoadingMore = false
            pageTask = nil
            if !(error is CancellationError || Task.isCancelled) { loadMoreError = error.localizedDescription }
        }
    }

    func selectFilter(field: String, value: String, api: any HomePgcServing) async {
        guard let conditions, conditions.contains(field: field, value: value) else { return }
        var next = usesFilters ? selectedFilters : conditions.defaultSelection
        next[field] = value
        guard !usesFilters || next != selectedFilters else { return }
        selectedFilters = next
        usesFilters = true
        // Clear the old category immediately so a failure cannot present its
        // cards as results of the newly selected filters.
        items = []
        total = nil
        await refresh(api: api)
    }

    func resetFilters(api: any HomePgcServing) async {
        selectedFilters = conditions?.defaultSelection ?? [:]
        usesFilters = true
        items = []
        total = nil
        await refresh(api: api)
    }

    func selectedValue(for field: String) -> String? {
        selectedFilters[field] ?? conditions?.defaultSelection[field]
    }

    func loadConditions(api: any HomePgcServing) {
        guard !conditionState.isLoading else { return }
        conditionTask?.cancel()
        conditionState = .loading
        let kind = kind
        conditionTask = Task { [weak self] in
            do {
                let conditions = try await api.fetchPgcIndexConditions(kind: kind)
                guard let self, !Task.isCancelled else { return }
                self.conditions = conditions
                self.conditionState = .loaded
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.conditionState = .failed(error.localizedDescription)
            }
        }
    }

    func loadTimeline(api: any HomePgcServing) {
        guard kind == .bangumi, !timelineState.isLoading else { return }
        timelineTask?.cancel()
        timelineState = .loading
        timelineTask = Task { [weak self] in
            async let bangumi = try? api.fetchPgcTimeline(types: 1)
            async let domestic = try? api.fetchPgcTimeline(types: 4)
            let (first, second) = await (bangumi, domestic)
            guard let self, !Task.isCancelled else { return }
            if first == nil && second == nil {
                self.timelineState = .failed("更新日历加载失败，可稍后重试。")
                return
            }
            self.timeline = Self.mergeTimeline(first ?? [], second ?? [])
            self.timelineState = .loaded
        }
    }

    static func mergeTimeline(_ first: [PgcTimelineDay], _ second: [PgcTimelineDay]) -> [PgcTimelineDay] {
        var merged = first
        for day in second {
            if let index = merged.firstIndex(where: { $0.timestamp == day.timestamp && $0.date == day.date }) {
                var seen = Set<Int>()
                let episodes = (merged[index].episodes + day.episodes).filter { seen.insert($0.id).inserted }
                merged[index] = PgcTimelineDay(date: day.date, timestamp: day.timestamp, dayOfWeek: day.dayOfWeek,
                    isToday: merged[index].isToday || day.isToday, episodes: episodes)
            } else { merged.append(day) }
        }
        return merged.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
    }
}
