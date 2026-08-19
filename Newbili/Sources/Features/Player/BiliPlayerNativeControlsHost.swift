import SwiftUI

struct BiliPlayerNativeControlsHost: View {
    let context: BiliPlayerViewRenderContext
    let renderState: BiliPlayerViewRenderState
    var actions: PlayerNativePlaybackControlsActions?
    var progressStyle: PlayerNativeProgressStyle = .standard

    var body: some View {
        PlayerNativePlaybackControls(
            clock: context.viewModel.playbackClock,
            metrics: renderState.controlMetrics,
            layout: context.configuration.controlLayout,
            canSeek: context.surfaceState.canSeek,
            isPlaying: context.surfaceState.isPlaying,
            isDanmakuEnabled: context.configuration.isDanmakuEnabled,
            showsDanmakuButton: context.configuration.controlLayout.isLive
                && context.configuration.onShowDanmakuSettings != nil,
            canToggleFullscreen: context.configuration.canToggleFullscreen,
            isFullscreenActive: context.configuration.isFullscreenActive,
            controlsAccessory: context.configuration.controlsAccessory,
            controlsCenterAccessory: context.configuration.controlsCenterAccessory,
            progressStyle: progressStyle,
            actions: actions ?? nativePlaybackControlsActions
        )
    }

    private var nativePlaybackControlsActions: PlayerNativePlaybackControlsActions {
        BiliPlayerNativeControlsActionBuilder(
            viewModel: context.viewModel,
            configuration: context.configuration,
            visibilityActions: renderState.visibilityActions,
            seekPreviewModel: context.seekPreviewModel,
            seekPreviewAPI: context.seekPreviewAPI,
            seekPreviewContext: context.seekPreviewContext,
            holdCurrentFrameForSeek: context.holdCurrentFrameForSeek,
            prepareUserSeekWarmup: context.prepareUserSeekWarmup,
            resetPreparedScrubProgress: context.resetPreparedScrubProgress
        ).actions
    }
}
