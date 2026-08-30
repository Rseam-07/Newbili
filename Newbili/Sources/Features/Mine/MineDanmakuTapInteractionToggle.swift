import SwiftUI

struct MineDanmakuTapInteractionToggle: View {
    @ObservedObject var libraryStore: LibraryStore

    var body: some View {
        Toggle(isOn: Binding(
            get: { libraryStore.danmakuTapInteractionEnabled },
            set: { libraryStore.setDanmakuTapInteractionEnabled($0) }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Label("启用点击弹幕", systemImage: "hand.tap")
                Text("点击弹幕后悬停，并在原位置复制、点赞或举报；关闭后触摸会直接交给播放器。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
