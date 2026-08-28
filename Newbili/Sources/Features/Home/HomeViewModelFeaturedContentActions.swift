import Foundation

extension HomeViewModel {
    func loadFeaturedSupplementaryContentIfNeeded(now: Date = Date()) async {
        guard mode == .recommend else { return }
        guard HomeFeaturedMixPolicy.shouldRefreshSupplement(
            hasCachedItems: !featuredPopularCells.isEmpty,
            lastRefreshDate: featuredPopularLastRefreshDate,
            now: now
        ) else { return }

        do {
            let videos = try await pageCoordinator.fetchFeaturedPopularVideos(
                limit: HomeFeaturedMixPolicy.maximumItemCount
            )
            guard !Task.isCancelled, mode == .recommend, !videos.isEmpty else { return }
            updateFeaturedPopularVideos(videos, refreshedAt: now)
        } catch is CancellationError {
            return
        } catch {
            // Supplementary content is deliberately best-effort. Keep the previous
            // popular cards, or fall back to the current recommendation feed.
        }
    }
}
