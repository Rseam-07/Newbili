import SwiftUI

struct InitialVideoDetailContentPage: View {
    let seedVideo: VideoItem
    let layoutWidth: CGFloat
    let tab: VideoDetailContentTab

    var body: some View {
        PlaybackDetailContentPage(
            layoutWidth: layoutWidth,
            topPadding: PlaybackDetailContentMetrics.topPadding,
            spacing: PlaybackDetailContentMetrics.spacing,
            background: VideoDetailTheme.background
        ) { _ in
            InitialVideoDetailContentPageBody(
                seedVideo: seedVideo,
                layoutWidth: layoutWidth,
                tab: tab
            )
        }
    }
}
