import SwiftUI

struct MineVideoDetailContentSettingsSection: View {
    @ObservedObject var libraryStore: LibraryStore

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { libraryStore.showsRelatedVideosInVideoDetail },
                set: { libraryStore.setShowsRelatedVideosInVideoDetail($0) }
            )) {
                settingsLabel(
                    title: "视频页显示相关视频",
                    detail: "关闭后不请求也不显示详情页相关推荐；听视频队列不受影响。",
                    systemImage: "rectangle.stack.badge.play"
                )
            }

            Toggle(isOn: Binding(
                get: { libraryStore.showsVideoCommentsInVideoDetail },
                set: { libraryStore.setShowsVideoCommentsInVideoDetail($0) }
            )) {
                settingsLabel(
                    title: "显示视频评论",
                    detail: "关闭后隐藏评论标签且不自动加载；从消息或链接直达的评论仍可打开。",
                    systemImage: "bubble.left.and.bubble.right"
                )
            }

            Toggle(isOn: Binding(
                get: { libraryStore.expandsVideoDescriptionByDefault },
                set: { libraryStore.setExpandsVideoDescriptionByDefault($0) }
            )) {
                settingsLabel(
                    title: "默认展开视频简介",
                    detail: "普通视频与番剧进入详情时默认展示完整简介，之后仍可随时手动收起。",
                    systemImage: "text.alignleft"
                )
            }
        } header: {
            Text("视频详情")
        } footer: {
            Text("汇总常用详情页开关；隐藏内容时会同步停止对应的自动加载，减少无用请求。")
        }
    }

    private func settingsLabel(
        title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
