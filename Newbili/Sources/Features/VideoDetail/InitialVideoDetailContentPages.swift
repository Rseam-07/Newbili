import SwiftUI

struct InitialVideoDetailDetailContentPage: View {
    let seedVideo: VideoItem
    let layoutWidth: CGFloat

    private var contentWidth: CGFloat {
        PlaybackDetailContentMetrics.contentWidth(for: layoutWidth)
    }

    private var shouldShowInitialPageMenuPlaceholder: Bool {
        !seedVideo.isPGCEpisode && (seedVideo.pages?.count ?? 1) > 1
    }

    var body: some View {
        InitialVideoDetailControls(
            titleText: seedVideo.title,
            contentWidth: contentWidth
        )
        .padding(.horizontal, PlaybackDetailContentMetrics.horizontalPadding)

        if shouldShowInitialPageMenuPlaceholder {
            InitialPageMenuPlaceholder(pageCount: seedVideo.pages?.count)
                .padding(.horizontal, PlaybackDetailContentMetrics.horizontalPadding)
        }

        if !seedVideo.isPGCEpisode {
            InitialRelatedSection(layoutWidth: layoutWidth)
        }
    }
}
