import Foundation

nonisolated enum HomeFeaturedContentSource: String, Equatable, Sendable {
    case currentFeed
    case popular
}

struct HomeFeaturedItem: Identifiable, Equatable {
    let cell: HomeVideoCellModel
    let source: HomeFeaturedContentSource

    var id: String { cell.id }
}

nonisolated struct HomeFeaturedSelection: Equatable, Sendable {
    let id: String
    let source: HomeFeaturedContentSource
}

nonisolated enum HomeFeaturedMixPolicy {
    static let maximumItemCount = 5
    static let maximumCurrentFeedItemCountWhenMixed = 4
    static let supplementaryCacheLifetime: TimeInterval = 15 * 60

    static func selections(
        currentFeedIDs: [String],
        popularIDs: [String],
        includesPopular: Bool
    ) -> [HomeFeaturedSelection] {
        let current = uniqueIDs(currentFeedIDs)
        guard includesPopular else {
            return current.prefix(maximumItemCount).map {
                HomeFeaturedSelection(id: $0, source: .currentFeed)
            }
        }

        let currentSet = Set(current)
        let popular = uniqueIDs(popularIDs).filter { !currentSet.contains($0) }
        guard let firstPopular = popular.first else {
            return current.prefix(maximumItemCount).map {
                HomeFeaturedSelection(id: $0, source: .currentFeed)
            }
        }

        var result = [HomeFeaturedSelection]()
        result.reserveCapacity(maximumItemCount)

        for id in current.prefix(2) {
            result.append(HomeFeaturedSelection(id: id, source: .currentFeed))
        }
        result.append(HomeFeaturedSelection(id: firstPopular, source: .popular))

        for id in current.dropFirst(2).prefix(maximumCurrentFeedItemCountWhenMixed - 2) {
            result.append(HomeFeaturedSelection(id: id, source: .currentFeed))
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
            for id in popular where !selectedIDs.contains(id) {
                result.append(HomeFeaturedSelection(id: id, source: .popular))
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
        reduceMotion: Bool,
        voiceOverEnabled: Bool
    ) -> Bool {
        itemCount > 1
            && isSceneActive
            && !isUserInteracting
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
