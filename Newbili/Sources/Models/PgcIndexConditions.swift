import Foundation

nonisolated struct PgcIndexConditions: Decodable, Equatable, Sendable {
    let order: [PgcIndexOrder]
    let filters: [PgcIndexFilter]

    enum CodingKeys: String, CodingKey { case order, filters = "filter" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var orders = Set<String>()
        var fields = Set<String>()
        order = try c.decodeIfPresent([PgcIndexOrder].self, forKey: .order)?.filter {
            !$0.field.isEmpty && orders.insert($0.field).inserted
        } ?? []
        filters = try c.decodeIfPresent([PgcIndexFilter].self, forKey: .filters)?.filter {
            PgcBrowseParameters.allowedFilterFields.contains($0.field) && !$0.values.isEmpty && fields.insert($0.field).inserted
        } ?? []
    }

    var defaultSelection: [String: String] {
        var values = filters.reduce(into: [String: String]()) { result, filter in
            result[filter.field] = filter.values.first?.keyword
        }
        values["order"] = order.first(where: { $0.field == "3" })?.field ?? order.first?.field
        return values
    }

    func contains(field: String, value: String) -> Bool {
        field == "order" ? order.contains { $0.field == value }
            : filters.first(where: { $0.field == field })?.values.contains { $0.keyword == value } == true
    }
}

nonisolated struct PgcIndexOrder: Decodable, Equatable, Identifiable, Sendable {
    var id: String { field }
    let field: String
    let name: String
    enum CodingKeys: String, CodingKey { case field, name }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        field = c.pgcScalar(for: .field) ?? ""
        name = c.pgcScalar(for: .name) ?? field
    }
}

nonisolated struct PgcIndexFilter: Decodable, Equatable, Identifiable, Sendable {
    var id: String { field }
    let field: String
    let name: String
    let values: [PgcIndexFilterValue]
    enum CodingKeys: String, CodingKey { case field, name, values }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        field = c.pgcScalar(for: .field) ?? ""
        name = c.pgcScalar(for: .name) ?? field
        var seen = Set<String>()
        values = try c.decodeIfPresent([PgcIndexFilterValue].self, forKey: .values)?.filter {
            !$0.keyword.isEmpty && seen.insert($0.keyword).inserted
        } ?? []
    }
}

nonisolated struct PgcIndexFilterValue: Decodable, Equatable, Identifiable, Sendable {
    var id: String { keyword }
    let keyword: String
    let name: String
    enum CodingKeys: String, CodingKey { case keyword, name }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keyword = c.pgcScalar(for: .keyword) ?? ""
        name = c.pgcScalar(for: .name) ?? keyword
    }
}

private nonisolated extension KeyedDecodingContainer {
    func pgcScalar(for key: Key) -> String? {
        if let text = try? decode(String.self, forKey: key) { return text }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        return nil
    }
}

nonisolated enum PgcBrowseParameters {
    static let allowedFilterFields: Set<String> = [
        "area", "style_id", "year", "season_status", "season_version", "is_finish",
        "copyright", "season_month", "spoken_language_type", "season_type", "producer_id", "sort", "order", "st"
    ]

    static func make(kind: HomePgcKind, page: Int, filters: [String: String]?) -> [String: String] {
        var query = [
            "st": "1", "order": "3", "season_version": "-1", "spoken_language_type": "-1",
            "area": "-1", "is_finish": "-1", "copyright": "-1", "season_status": "-1",
            "season_month": "-1", "year": "-1", "style_id": "-1", "sort": "0",
            "pagesize": "20", "type": filters == nil ? "1" : "0", "page": String(max(1, page))
        ]
        if let indexType = kind.indexType {
            query["index_type"] = String(indexType)
        } else {
            query["season_type"] = "1"
        }
        for (field, value) in filters ?? [:] where allowedFilterFields.contains(field) {
            query[field] = value
        }
        return query
    }
}
