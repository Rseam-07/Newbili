import SwiftUI

struct AudioMiniPlayerBottomAccessory: View {
    @ObservedObject var coordinator: AudioMiniPlayerCoordinator
    let openDetail: () -> Void

    var body: some View {
        if let snapshot = coordinator.snapshot {
            HStack(spacing: 10) {
                Button(action: openDetail) {
                    HStack(spacing: 10) {
                        artwork(snapshot)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapshot.video.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(snapshot.ownerName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: coordinator.togglePlayback) {
                    Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(snapshot.isPlaying ? "暂停" : "播放")

                if snapshot.canPlayNext {
                    Button(action: coordinator.playNext) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 30, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("下一项")
                }

                Button(action: coordinator.close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭音频播放")
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        }
    }

    private func artwork(_ snapshot: AudioMiniPlayerSnapshot) -> some View {
        CachedRemoteImage(
            url: snapshot.artworkURLString.flatMap(URL.init(string:)),
            targetPixelSize: 160,
            animatesAppearance: false
        ) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            BiliMediaPlaceholder(style: .video, iconSize: 14)
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
