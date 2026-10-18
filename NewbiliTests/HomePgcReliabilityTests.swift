import Combine
import Foundation
import Testing
@testable import bili

@Suite(.serialized)
@MainActor
struct HomePgcReliabilityTests {
    @Test func unavailableCalendarAndConditionsDoNotBlockPlayableResults() async throws {
        let api = ControlledPgcService()
        api.metadataFails = true
        let model = HomePgcBrowseViewModel(kind: .bangumi)
        let loading = Task { await model.loadInitial(api: api) }
        await api.started("1/default")
        try api.finish("1/default", seasonID: 1)
        await loading.value
        #expect(model.items.map(\.id) == [1])
        #expect(model.state == .loaded)
        for await state in model.$timelineState.values {
            if case .failed = state { break }
        }
        #expect(model.items.map(\.id) == [1])
    }

    @Test func changingFiltersRejectsAnOlderResponseThatIgnoresCancellation() async throws {
        let api = ControlledPgcService()
        let model = HomePgcBrowseViewModel(kind: .cinema)
        model.loadConditions(api: api)
        for await state in model.$conditionState.values { if state == .loaded { break } }
        let old = Task { await model.selectFilter(field: "year", value: "2024", api: api) }
        await api.started("1/2024")
        let current = Task { await model.selectFilter(field: "year", value: "2025", api: api) }
        await api.started("1/2025")
        try api.finish("1/2025", seasonID: 2)
        await current.value
        try api.finish("1/2024", seasonID: 1)
        await old.value
        #expect(model.selectedFilters["year"] == "2025")
        #expect(model.items.map(\.id) == [2])
        #expect(model.state == .loaded)
    }

    @Test func failedPaginationCanBeRetriedWithoutSkippingThePage() async throws {
        let api = ControlledPgcService()
        let model = HomePgcBrowseViewModel(kind: .cinema)
        let first = Task { await model.refresh(api: api) }
        await api.started("1/default")
        try api.finish("1/default", seasonID: 1)
        await first.value
        let failed = Task { await model.loadMore(api: api) }
        await api.started("2/default")
        api.fail("2/default")
        await failed.value
        #expect(model.loadMoreError != nil)
        #expect(model.items.map(\.id) == [1])
        let retry = Task { await model.loadMore(api: api) }
        await api.started("2/default")
        try api.finish("2/default", seasonID: 2)
        await retry.value
        #expect(api.pages == [1, 2, 2])
        #expect(model.items.map(\.id) == [1, 2])
        #expect(model.loadMoreError == nil)
    }

    @Test func conditionsDecodeScalarValuesAndProtectPagingParameters() throws {
        let conditions = try ControlledPgcService.decodeConditions()
        #expect(conditions.order.map(\.field) == ["3", "6"])
        #expect(conditions.contains(field: "year", value: "2024"))
        #expect(conditions.filters.map(\.field) == ["year"])
        let query = PgcBrowseParameters.make(kind: .cinema, page: 2,
            filters: ["year": "2025", "order": "6", "page": "999", "index_type": "1", "pagesize": "999"])
        #expect(query["year"] == "2025")
        #expect(query["order"] == "6")
        #expect(query["page"] == "2")
        #expect(query["index_type"] == "102")
        #expect(query["pagesize"] == "20")
        #expect(query["season_type"] == nil)
    }

    @Test func cancelledPaginationDoesNotKeepTheLoadingSpinner() async throws {
        let api = ControlledPgcService()
        let model = HomePgcBrowseViewModel(kind: .cinema)
        let first = Task { await model.refresh(api: api) }
        await api.started("1/default")
        try api.finish("1/default", seasonID: 1)
        await first.value
        let more = Task { await model.loadMore(api: api) }
        await api.started("2/default")
        more.cancel()
        try api.finish("2/default", seasonID: 2)
        await more.value
        #expect(!model.isLoadingMore)
        #expect(model.canLoadMore)
        #expect(model.items.map(\.id) == [1])
    }
}

@MainActor
private final class ControlledPgcService: HomePgcServing {
    var metadataFails = false
    var pages = [Int]()
    private var pending = [String: CheckedContinuation<PgcBrowsePage, Error>]()
    private var waiters = [String: CheckedContinuation<Void, Never>]()

    func started(_ key: String) async {
        if pending[key] != nil { return }
        await withCheckedContinuation { waiters[key] = $0 }
    }
    func finish(_ key: String, seasonID: Int) throws {
        let data = Data("{\"list\":[{\"season_id\":\(seasonID),\"title\":\"作品\(seasonID)\"}],\"has_next\":1,\"total\":10}".utf8)
        pending.removeValue(forKey: key)?.resume(returning: try JSONDecoder().decode(PgcBrowsePage.self, from: data))
    }
    func fail(_ key: String) { pending.removeValue(forKey: key)?.resume(throwing: BiliAPIError.emptyData) }
    func fetchPgcBrowse(kind: HomePgcKind, page: Int, filters: [String: String]?) async throws -> PgcBrowsePage {
        pages.append(page)
        return try await withCheckedThrowingContinuation {
            let key = "\(page)/\(filters?["year"] ?? "default")"
            pending[key] = $0
            waiters.removeValue(forKey: key)?.resume()
        }
    }
    func fetchPgcIndexConditions(kind: HomePgcKind) async throws -> PgcIndexConditions {
        if metadataFails { throw BiliAPIError.emptyData }
        return try Self.decodeConditions()
    }
    func fetchPgcTimeline(types: Int) async throws -> [PgcTimelineDay] {
        if metadataFails { throw BiliAPIError.emptyData }
        return []
    }
    static func decodeConditions() throws -> PgcIndexConditions {
        try JSONDecoder().decode(PgcIndexConditions.self, from: Data(#"{"order":[{"field":"3","name":"追番人数"},{"field":6,"name":"评分"}],"filter":[{"field":"year","name":"年份","values":[{"keyword":"-1","name":"全部"},{"keyword":2024,"name":"2024"},{"keyword":"2025","name":"2025"}]},{"field":"page","name":"不应覆盖分页","values":[{"keyword":"999","name":"错误"}]}]}"#.utf8))
    }
}
