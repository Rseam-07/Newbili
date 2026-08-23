import Foundation

enum HomePrimarySection: String, CaseIterable, Identifiable, Hashable {
    case recommend
    case popular
    case regions
    case bangumi
    case cinema

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommend: "推荐"
        case .popular: "热门"
        case .regions: "分区"
        case .bangumi: "番剧"
        case .cinema: "影视"
        }
    }

    var systemImage: String {
        switch self {
        case .recommend: "wand.and.stars.inverse"
        case .popular: "chart.line.uptrend.xyaxis"
        case .regions: "square.grid.2x2"
        case .bangumi: "sparkles.tv"
        case .cinema: "film.stack"
        }
    }

    var feedMode: HomeFeedMode? {
        switch self {
        case .recommend: .recommend
        case .popular: .popular
        case .regions, .bangumi, .cinema: nil
        }
    }
}
