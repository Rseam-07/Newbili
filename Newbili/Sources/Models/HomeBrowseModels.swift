import Foundation

nonisolated enum HomePgcKind: String, CaseIterable, Identifiable, Sendable {
    case bangumi
    case cinema

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bangumi: "番剧"
        case .cinema: "影视"
        }
    }

    var indexType: Int? {
        self == .cinema ? 102 : nil
    }
}

nonisolated struct PgcBrowsePage: Decodable, Sendable {
    let list: [PgcBrowseItem]
    let hasNext: Bool
    let total: Int?

    private enum CodingKeys: String, CodingKey {
        case list, total
        case hasNext = "has_next"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        list = try container.decodeIfPresent([PgcBrowseItem].self, forKey: .list) ?? []
        if let value = try? container.decode(Bool.self, forKey: .hasNext) {
            hasNext = value
        } else if let value = try? container.decode(Int.self, forKey: .hasNext) {
            hasNext = value != 0
        } else {
            hasNext = false
        }
        if let value = try? container.decode(Int.self, forKey: .total) {
            total = value
        } else if let value = try? container.decode(String.self, forKey: .total) {
            total = Int(value)
        } else {
            total = nil
        }
    }
}

nonisolated struct PgcBrowseItem: Decodable, Hashable, Identifiable, Sendable {
    let seasonID: Int
    let mediaID: Int?
    let title: String
    let subtitle: String?
    let cover: String?
    let badge: String?
    let indexShow: String?
    let order: String?
    let score: String?
    let firstEpisode: PgcBrowseFirstEpisode?

    var id: Int { seasonID }

    private enum CodingKeys: String, CodingKey {
        case title, cover, badge, order, score
        case seasonID = "season_id"
        case mediaID = "media_id"
        case subtitle = "subTitle"
        case indexShow = "index_show"
        case firstEpisode = "first_ep"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seasonID = Self.lossyInt(container, .seasonID) ?? 0
        mediaID = Self.lossyInt(container, .mediaID)
        title = (try? container.decode(String.self, forKey: .title))?.removingHTMLTags() ?? "未命名作品"
        subtitle = try? container.decodeIfPresent(String.self, forKey: .subtitle)
        cover = try? container.decodeIfPresent(String.self, forKey: .cover)
        badge = try? container.decodeIfPresent(String.self, forKey: .badge)
        indexShow = try? container.decodeIfPresent(String.self, forKey: .indexShow)
        order = try? container.decodeIfPresent(String.self, forKey: .order)
        if let value = try? container.decodeIfPresent(String.self, forKey: .score) {
            score = value
        } else if let value = try? container.decodeIfPresent(Double.self, forKey: .score) {
            score = String(format: "%.1f", value)
        } else {
            score = nil
        }
        firstEpisode = try? container.decodeIfPresent(PgcBrowseFirstEpisode.self, forKey: .firstEpisode)
    }

    var route: PgcSeasonRoute? {
        guard seasonID > 0 else { return nil }
        return PgcSeasonRoute(seasonID: seasonID, title: title, cover: cover)
    }

    private static func lossyInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) { return Int(value) }
        return nil
    }
}

nonisolated struct PgcBrowseFirstEpisode: Decodable, Hashable, Sendable {
    let episodeID: Int?
    let cover: String?

    private enum CodingKeys: String, CodingKey {
        case cover
        case episodeID = "ep_id"
    }
}

nonisolated struct PgcTimelineDay: Decodable, Hashable, Identifiable, Sendable {
    let date: String
    let timestamp: Int?
    let dayOfWeek: Int?
    let isToday: Bool
    let episodes: [PgcTimelineEpisode]

    var id: String { "\(timestamp ?? 0)-\(date)" }

    init(
        date: String,
        timestamp: Int?,
        dayOfWeek: Int?,
        isToday: Bool,
        episodes: [PgcTimelineEpisode]
    ) {
        self.date = date
        self.timestamp = timestamp
        self.dayOfWeek = dayOfWeek
        self.isToday = isToday
        self.episodes = episodes
    }

    private enum CodingKeys: String, CodingKey {
        case date, episodes
        case timestamp = "date_ts"
        case dayOfWeek = "day_of_week"
        case isToday = "is_today"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = (try? container.decode(String.self, forKey: .date)) ?? ""
        timestamp = try? container.decodeIfPresent(Int.self, forKey: .timestamp)
        dayOfWeek = try? container.decodeIfPresent(Int.self, forKey: .dayOfWeek)
        if let value = try? container.decodeIfPresent(Bool.self, forKey: .isToday) {
            isToday = value
        } else {
            isToday = (try? container.decodeIfPresent(Int.self, forKey: .isToday)) == 1
        }
        episodes = (try? container.decodeIfPresent([PgcTimelineEpisode].self, forKey: .episodes)) ?? []
    }

    var displayDate: String {
        if isToday { return "今天" }
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        guard let dayOfWeek, (1...7).contains(dayOfWeek) else { return date }
        return weekdays[dayOfWeek % 7]
    }
}

nonisolated struct PgcTimelineEpisode: Decodable, Hashable, Identifiable, Sendable {
    let episodeID: Int
    let seasonID: Int
    let title: String
    let cover: String?
    let episodeCover: String?
    let publishIndex: String?
    let publishTime: String?
    let published: Bool

    var id: Int { episodeID }

    private enum CodingKeys: String, CodingKey {
        case title, cover, published
        case episodeID = "episode_id"
        case seasonID = "season_id"
        case episodeCover = "ep_cover"
        case publishIndex = "pub_index"
        case publishTime = "pub_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodeID = (try? container.decode(Int.self, forKey: .episodeID)) ?? 0
        seasonID = (try? container.decode(Int.self, forKey: .seasonID)) ?? 0
        title = (try? container.decode(String.self, forKey: .title)) ?? "未命名作品"
        cover = try? container.decodeIfPresent(String.self, forKey: .cover)
        episodeCover = try? container.decodeIfPresent(String.self, forKey: .episodeCover)
        publishIndex = try? container.decodeIfPresent(String.self, forKey: .publishIndex)
        publishTime = try? container.decodeIfPresent(String.self, forKey: .publishTime)
        if let value = try? container.decodeIfPresent(Bool.self, forKey: .published) {
            published = value
        } else {
            published = (try? container.decodeIfPresent(Int.self, forKey: .published)) == 1
        }
    }

    var route: PgcSeasonRoute? {
        guard seasonID > 0 else { return nil }
        return PgcSeasonRoute(seasonID: seasonID, title: title, cover: cover)
    }
}

nonisolated struct PgcRankPayload: Decodable, Sendable {
    let list: [PgcRankItem]
}

nonisolated struct PgcRankItem: Decodable, Hashable, Identifiable, Sendable {
    let cover: String?
    let title: String
    let url: String?
    let newEpisode: PgcRankNewEpisode?
    let stat: PgcRankStat?

    var id: String { url ?? "\(title)-\(cover ?? "")" }

    private enum CodingKeys: String, CodingKey {
        case cover, title, url, stat
        case newEpisode = "new_ep"
    }

    var route: PgcSeasonRoute? {
        guard let seasonID = routeID(prefix: "ss") else { return nil }
        return PgcSeasonRoute(seasonID: seasonID, title: title, cover: cover)
    }

    private func routeID(prefix: String) -> Int? {
        guard let url,
              let range = url.range(of: "\(prefix)[0-9]+", options: .regularExpression)
        else { return nil }
        return Int(url[range].dropFirst(prefix.count))
    }
}

nonisolated struct PgcRankNewEpisode: Decodable, Hashable, Sendable {
    let indexShow: String?

    private enum CodingKeys: String, CodingKey {
        case indexShow = "index_show"
    }
}

nonisolated struct PgcRankStat: Decodable, Hashable, Sendable {
    let follow: Int?
    let view: Int?
}
