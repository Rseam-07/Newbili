import Foundation

nonisolated enum HomeFeaturedContentSource: String, Equatable, Sendable {
    case currentFeed
    case popular
    case activity
}

struct HomeFeaturedItem: Identifiable, Equatable {
    let cell: HomeVideoCellModel
    let source: HomeFeaturedContentSource
    let destinationURL: URL?

    init(
        cell: HomeVideoCellModel,
        source: HomeFeaturedContentSource,
        destinationURL: URL? = nil
    ) {
        self.cell = cell
        self.source = source
        self.destinationURL = destinationURL
    }

    init(activity: HomeActivityBanner, index: Int) {
        let placeholderVideo = VideoItem(
            bvid: "activity-\(activity.id)",
            aid: nil,
            title: activity.name,
            pic: activity.pic,
            desc: activity.label,
            duration: nil,
            pubdate: nil,
            owner: VideoOwner(mid: 0, name: "哔哩哔哩活动", face: nil),
            stat: nil,
            cid: nil,
            pages: nil,
            dimension: nil
        )
        self.init(
            cell: HomeVideoCellModel(video: placeholderVideo, index: index),
            source: .activity,
            destinationURL: activity.destinationURL
        )
    }

    var id: String { cell.id }

    var preloadVideo: VideoItem? {
        source == .activity ? nil : cell.video
    }
}

nonisolated struct HomeFeaturedSelection: Equatable, Sendable {
    let id: String
    let source: HomeFeaturedContentSource
}

nonisolated enum HomeFeaturedMixPolicy {
    static let maximumItemCount = 5
    static let supplementaryCacheLifetime: TimeInterval = 15 * 60

    static func selections(
        currentFeedIDs: [String],
        popularIDs: [String],
        activityIDs: [String] = [],
        includesPopular: Bool,
        includesActivity: Bool = false
    ) -> [HomeFeaturedSelection] {
        let current = uniqueIDs(currentFeedIDs)
        let popular = includesPopular ? uniqueIDs(popularIDs) : []
        let activity = includesActivity ? uniqueIDs(activityIDs) : []
        guard !popular.isEmpty || !activity.isEmpty else {
            return current.prefix(maximumItemCount).map {
                HomeFeaturedSelection(id: $0, source: .currentFeed)
            }
        }

        let currentSet = Set(current)
        let supplementaryPopular = popular.filter { !currentSet.contains($0) }
        let supplementaryActivities = activity.filter { !currentSet.contains($0) }

        var result = [HomeFeaturedSelection]()
        result.reserveCapacity(maximumItemCount)

        for id in current.prefix(2) {
            result.append(HomeFeaturedSelection(id: id, source: .currentFeed))
        }

        if let firstPopular = supplementaryPopular.first {
            result.append(HomeFeaturedSelection(id: firstPopular, source: .popular))
        }

        if let firstActivity = supplementaryActivities.first,
           result.count < maximumItemCount {
            result.append(HomeFeaturedSelection(id: firstActivity, source: .activity))
        }

        for id in current.dropFirst(2) {
            result.append(HomeFeaturedSelection(id: id, source: .currentFeed))
            if result.count == maximumItemCount { break }
        }

        if result.count < maximumItemCount {
            let selectedIDs = Set(result.map(\.id))
            for id in current where !selectedIDs.contains(id) {
                result.append(HomeFeaturedSelection(id: id, source: .currentFeed))
                if result.count == maximumItemCount { break }
            }
        }

        if result.count < maximumItemCount {
            let selectedIDs = Set(result.map(\.id))
            for id in supplementaryPopular where !selectedIDs.contains(id) {
                result.append(HomeFeaturedSelection(id: id, source: .popular))
                if result.count == maximumItemCount { break }
            }
        }

        if result.count < maximumItemCount {
            let selectedIDs = Set(result.map(\.id))
            for id in supplementaryActivities where !selectedIDs.contains(id) {
                result.append(HomeFeaturedSelection(id: id, source: .activity))
                if result.count == maximumItemCount { break }
            }
        }

        return Array(result.prefix(maximumItemCount))
    }

    static func nextID(in ids: [String], after currentID: String) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let index = ids.firstIndex(of: currentID) else { return ids.first }
        return ids[(index + 1) % ids.count]
    }

    static func previousID(in ids: [String], before currentID: String) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let index = ids.firstIndex(of: currentID) else { return ids.first }
        return ids[(index - 1 + ids.count) % ids.count]
    }

    static func shouldAutoAdvance(
        itemCount: Int,
        isSceneActive: Bool,
        isUserInteracting: Bool,
        isPausedByUser: Bool = false,
        reduceMotion: Bool,
        voiceOverEnabled: Bool
    ) -> Bool {
        itemCount > 1
            && isSceneActive
            && !isUserInteracting
            && !isPausedByUser
            && !reduceMotion
            && !voiceOverEnabled
    }

    static func shouldRefreshSupplement(
        hasCachedItems: Bool,
        lastRefreshDate: Date?,
        now: Date
    ) -> Bool {
        guard hasCachedItems, let lastRefreshDate else { return true }
        return now.timeIntervalSince(lastRefreshDate) >= supplementaryCacheLifetime
    }

    private static func uniqueIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

nonisolated struct HomeActivityBanner: Decodable, Equatable, Identifiable, Sendable {
    let id: Int
    let position: Int
    let name: String
    let pic: String
    let url: String
    let label: String?
    let isAdLocation: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case position = "pos_num"
        case name
        case pic
        case url
        case label
        case isAdLocation = "is_ad_loc"
    }

    var destinationURL: URL? {
        let normalized = url
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .normalizedBiliURL()
        guard let destination = URL(string: normalized),
              let host = destination.host?.lowercased(),
              host == "bilibili.com" || host.hasSuffix(".bilibili.com")
        else { return nil }
        return destination
    }

    var isEligibleEditorialActivity: Bool {
        guard !isAdLocation,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !pic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let destinationURL
        else { return false }

        let path = destinationURL.path.lowercased()
        return path.contains("/blackboard/")
            || path.contains("/festival/")
            || path.contains("/activity/")
    }
}
