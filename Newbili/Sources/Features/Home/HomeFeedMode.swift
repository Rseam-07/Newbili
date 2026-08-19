import Foundation

enum HomeFeedMode: String, CaseIterable, Hashable, Identifiable {
    case recommend
    case popular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommend:
            return "推荐"
        case .popular:
            return "热门"
        }
    }

    var systemImage: String {
        switch self {
        case .recommend:
            return "wand.and.stars.inverse"
        case .popular:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

nonisolated enum HomeNavigationModeSwitcherExperiment {
    static let storageKey = "cc.bili.home.navigationModeSwitcherExperimentEnabled.v1"
    static let defaultIsEnabled = true
}
