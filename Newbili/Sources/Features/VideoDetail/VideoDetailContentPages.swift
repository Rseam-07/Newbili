import SwiftUI

struct VideoDetailContentPage: View {
    @ObservedObject var viewModel: VideoDetailViewModel
    let layoutWidth: CGFloat
    let tab: VideoDetailContentTab
    let runtimeSettings: VideoDetailRuntimeSettingsSnapshot
    let onShowNetworkDiagnostics: () -> Void
    let onShowFavoriteFolders: () -> Void
    let onShowCoinPicker: () -> Void
    let onReply: (Comment) -> Void

    var body: some View {
        PlaybackDetailContentPage(
            layoutWidth: layoutWidth,
            topPadding: PlaybackDetailContentMetrics.topPadding,
            spacing: PlaybackDetailContentMetrics.spacing,
            background: VideoDetailTheme.background
        ) { _ in
            VideoDetailContentPageBody(
                viewModel: viewModel,
                layoutWidth: layoutWidth,
                tab: tab,
                runtimeSettings: runtimeSettings,
                onShowNetworkDiagnostics: onShowNetworkDiagnostics,
                onShowFavoriteFolders: onShowFavoriteFolders,
                onShowCoinPicker: onShowCoinPicker,
                onReply: onReply
            )
        }
    }
}
