import Foundation

extension HomeViewModel {
    func loadFeaturedSupplementaryContentIfNeeded(now: Date = Date()) async {
        guard mode == .recommend else { return }
        guard HomeFeaturedMixPolicy.shouldRefreshSupplement(
            hasCachedItems: !featuredPopularCells.isEmpty || !featuredActivityBanners.isEmpty,
            lastRefreshDate: featuredPopularLastRefreshDate,
            now: now
        ) else { return }

        async let popularRequest = try? pageCoordinator.fetchFeaturedPopularVideos(
            limit: HomeFeaturedMixPolicy.maximumItemCount
        )
        async let activityRequest = try? pageCoordinator.fetchFeaturedActivityBanners(
            limit: 2
        )
        let (videos, activities) = await (popularRequest, activityRequest)

        guard !Task.isCancelled, mode == .recommend else { return }
        if let videos, !videos.isEmpty {
            updateFeaturedPopularVideos(videos, refreshedAt: now)
        }
        if let activities, !activities.isEmpty {
            updateFeaturedActivityBanners(activities, refreshedAt: now)
        }
        // Supplementary content is deliberately best-effort. Keep the previous cards,
        // or fall back to the current recommendation feed when either endpoint fails.
    }
}
