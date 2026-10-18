import Foundation

nonisolated struct SearchVideoFilters: Equatable {
    var duration: SearchVideoDuration = .all
    var zone: SearchVideoZone = .all
    var published: SearchVideoPublished = .all

    var isActive: Bool { self != Self() }
    var summary: String {
        [duration == .all ? nil : duration.title,
         zone == .all ? nil : zone.title,
         published == .all ? nil : published.title]
            .compactMap { $0 }.joined(separator: " · ")
    }

    func parameters(now: Date = Date()) -> [String: String] {
        var values: [String: String] = [:]
        if duration != .all { values["duration"] = String(duration.rawValue) }
        if zone != .all { values["tids"] = String(zone.rawValue) }
        if let days = published.days {
            let end = max(0, Int(now.timeIntervalSince1970))
            values["pubtime_begin_s"] = String(max(0, end - days * 86_400))
            values["pubtime_end_s"] = String(end)
        }
        return values
    }
}

nonisolated enum SearchVideoDuration: Int, CaseIterable, Identifiable {
    case all, underTenMinutes, tenToThirtyMinutes, thirtyToSixtyMinutes, overSixtyMinutes
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .all: "全部时长"
        case .underTenMinutes: "10 分钟以下"
        case .tenToThirtyMinutes: "10–30 分钟"
        case .thirtyToSixtyMinutes: "30–60 分钟"
        case .overSixtyMinutes: "60 分钟以上"
        }
    }
}

nonisolated enum SearchVideoZone: Int, CaseIterable, Identifiable {
    case all = 0, animation = 1, bangumi = 13, chineseAnimation = 167
    case music = 3, dance = 129, game = 4, knowledge = 36, technology = 188
    case sports = 234, car = 223, life = 160, food = 221, animals = 217
    case remix = 119, fashion = 115, news = 202, entertainment = 5
    case film = 181, documentary = 177, movie = 23, television = 11
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .all: "全部分区"
        case .animation: "动画"
        case .bangumi: "番剧"
        case .chineseAnimation: "国创"
        case .music: "音乐"
        case .dance: "舞蹈"
        case .game: "游戏"
        case .knowledge: "知识"
        case .technology: "科技"
        case .sports: "运动"
        case .car: "汽车"
        case .life: "生活"
        case .food: "美食"
        case .animals: "动物"
        case .remix: "鬼畜"
        case .fashion: "时尚"
        case .news: "资讯"
        case .entertainment: "娱乐"
        case .film: "影视"
        case .documentary: "纪录片"
        case .movie: "电影"
        case .television: "电视剧"
        }
    }
}

nonisolated enum SearchVideoPublished: String, CaseIterable, Identifiable {
    case all, day, week, halfYear
    var id: Self { self }
    var title: String {
        switch self {
        case .all: "不限时间"
        case .day: "最近一天"
        case .week: "最近一周"
        case .halfYear: "最近半年"
        }
    }
    var days: Int? {
        switch self {
        case .all: nil
        case .day: 1
        case .week: 7
        case .halfYear: 180
        }
    }
}
