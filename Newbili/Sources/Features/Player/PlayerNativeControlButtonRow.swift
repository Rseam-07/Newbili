import SwiftUI

struct PlayerNativeControlButtonRow: View {
    let clock: PlayerPlaybackClock
    let metrics: PlayerNativeControlMetrics
    let layout: BiliPlayerControlLayout
    let isPlaying: Bool
    let isDanmakuEnabled: Bool
    let showsDanmakuButton: Bool
    let showsSendDanmakuButton: Bool
    let isPictureInPictureSupported: Bool
    let isPictureInPictureActive: Bool
    let canToggleFullscreen: Bool
    let isFullscreenActive: Bool
    let controlsAccessory: AnyView?
    let controlsCenterAccessory: AnyView?
    let actions: PlayerNativePlaybackControlsActions

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 520
            HStack(spacing: metrics.controlSpacing) {
                if layout.showsPlaybackToggle {
                    icon(isPlaying ? "pause.fill" : "play.fill", title: isPlaying ? "暂停" : "播放", action: actions.onTogglePlayback)
                }
                if layout.showsTimeLabel, controlsCenterAccessory == nil {
                    PlayerNativeTimeLabel(clock: clock, metrics: metrics)
                        .frame(width: min(metrics.timeLabelWidth, compact ? 86 : 104), height: metrics.controlHeight)
                }
                if layout.isLive, let controlsAccessory { controlsAccessory }
                Spacer(minLength: 0)
                // Center accessories participate in layout instead of overlapping
                // the time label and trailing buttons in a ZStack.
                if let controlsCenterAccessory { controlsCenterAccessory; Spacer(minLength: 0) }
                if !layout.isLive, let controlsAccessory { controlsAccessory }
                if showsDanmakuButton {
                    icon(danmakuControlSymbol,
                         title: layout.isLive ? "弹幕设置" : (isDanmakuEnabled ? "关闭弹幕" : "开启弹幕"),
                         action: actions.onToggleDanmaku)
                }
                if compact {
                    if showsSendDanmakuButton || pictureInPicturePresentation.isVisible { secondaryControls }
                } else {
                    if showsSendDanmakuButton { icon("paperplane.fill", title: "发送弹幕", action: actions.onSendDanmaku) }
                    if pictureInPicturePresentation.isVisible { pictureInPictureButton }
                }
                if canToggleFullscreen {
                    icon(isFullscreenActive ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                         title: isFullscreenActive ? "退出全屏" : "全屏", action: actions.onToggleFullscreen)
                }
            }
            .frame(width: proxy.size.width, height: max(44, metrics.controlHeight))
        }
        .frame(height: max(44, metrics.controlHeight))
    }

    private func icon(_ name: String, title: String, action: @escaping () -> Void) -> some View {
        PlayerNativeGlassIconButton(systemName: name, accessibilityLabel: title, metrics: metrics, action: action)
    }

    private var secondaryControls: some View {
        Menu {
            if showsSendDanmakuButton {
                Button("发送弹幕", systemImage: "paperplane", action: actions.onSendDanmaku)
            }
            if pictureInPicturePresentation.isVisible {
                Button(pictureInPicturePresentation.accessibilityLabel,
                       systemImage: pictureInPicturePresentation.systemName, action: actions.onTogglePictureInPicture)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: metrics.iconSize, weight: .semibold))
                .frame(width: metrics.controlHeight, height: metrics.controlHeight)
        }
        .biliPlayerCompactGlassCircle(metrics: metrics)
        .accessibilityLabel("更多播放操作")
    }

    private var pictureInPictureButton: some View {
        icon(pictureInPicturePresentation.systemName, title: pictureInPicturePresentation.accessibilityLabel,
             action: actions.onTogglePictureInPicture)
            .accessibilityValue(pictureInPicturePresentation.accessibilityValue)
    }

    private var danmakuControlSymbol: String {
        layout.isLive ? "slider.horizontal.3" : (isDanmakuEnabled ? "text.bubble.fill" : "text.bubble")
    }

    private var pictureInPicturePresentation: PlayerNativePictureInPictureControlPresentation {
        PlayerNativePictureInPictureControlPresentation(isSupported: isPictureInPictureSupported, isActive: isPictureInPictureActive)
    }
}

struct PlayerNativePictureInPictureControlPresentation: Equatable {
    let isVisible: Bool
    let systemName: String
    let accessibilityLabel: String
    let accessibilityValue: String

    init(isSupported: Bool, isActive: Bool) {
        isVisible = isSupported
        systemName = isActive ? "pip.exit" : "pip.enter"
        accessibilityLabel = isActive ? "关闭画中画" : "开启画中画"
        accessibilityValue = isActive ? "已开启" : "已关闭"
    }
}
