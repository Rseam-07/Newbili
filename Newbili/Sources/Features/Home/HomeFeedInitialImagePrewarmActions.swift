import Foundation

extension HomeFeedMediaPreloadCoordinator {
    func prewarmInitialImagesBeforePublishing(_ videos: [VideoItem]) async {
        let environment = PlaybackEnvironment.current
        let layout = libraryStore.homeFeedLayout
        let prefetchPlan = HomeFeedImagePrefetchPlan.make(
            for: videos,
            profile: resolvedImagePrefetchProfile(for: layout),
            limit: HomeFeedImagePrefetchPolicy.initialPrefetchLimit(
                layout: layout,
                isConservative: environment.shouldPreferConservativePlayback
            )
        )
        guard !prefetchPlan.coverSources.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await RemoteImageCache.shared.prefetch(
                    prefetchPlan.coverSources,
                    targetPixelSize: prefetchPlan.coverTargetPixelSize,
                    maximumConcurrentLoads: HomeFeedImagePrefetchPolicy.maximumConcurrentLoads(
                        isConservative: environment.shouldPreferConservativePlayback
                    )
                )
            }
            group.addTask {
                try? await Task.sleep(
                    nanoseconds: HomeFeedImagePrefetchPolicy.initialPrewarmDeadlineNanoseconds(
                        isConservative: environment.shouldPreferConservativePlayback
                    )
                )
            }
            _ = await group.next()
            group.cancelAll()
        }
    }
}
