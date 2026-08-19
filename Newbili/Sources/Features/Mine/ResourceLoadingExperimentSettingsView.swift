import SwiftUI

struct ResourceLoadingExperimentSettingsView: View {
    @ObservedObject var libraryStore: LibraryStore

    var body: some View {
        Form {
            Section("小功能") {
                featureToggle(
                    title: "首屏资源优先",
                    systemImage: "rectangle.3.group",
                    isOn: Binding(
                        get: { libraryStore.resourceLoadingFirstScreenPriorityEnabled },
                        set: { libraryStore.setResourceLoadingFirstScreenPriorityEnabled($0) }
                    ),
                    detail: "首页和动态刚打开时，先让可见封面、头像加载；后台视频预热会稍后再跑，减少封面慢出来的感觉。"
                )

                featureToggle(
                    title: "屏幕图片提权",
                    systemImage: "photo.badge.checkmark",
                    isOn: Binding(
                        get: { libraryStore.resourceLoadingVisibleImagePriorityEnabled },
                        set: { libraryStore.setResourceLoadingVisibleImagePriorityEnabled($0) }
                    ),
                    detail: "正在屏幕里的图片比后台预取更优先。快速滑到新卡片时，封面不容易排在后台任务后面。"
                )

                featureToggle(
                    title: "重复接口合并",
                    systemImage: "arrow.triangle.merge",
                    isOn: Binding(
                        get: { libraryStore.resourceLoadingReadRequestCoalescingEnabled },
                        set: { libraryStore.setResourceLoadingReadRequestCoalescingEnabled($0) }
                    ),
                    detail: "短时间内多个页面要同一份只读数据时只发一次请求，其他页面共用结果，减少反复加载。"
                )

                featureToggle(
                    title: "动态页快速恢复",
                    systemImage: "bolt.horizontal.circle",
                    isOn: Binding(
                        get: { libraryStore.resourceLoadingDynamicDiskSnapshotEnabled },
                        set: { libraryStore.setResourceLoadingDynamicDiskSnapshotEnabled($0) }
                    ),
                    detail: "保存短时间的动态首页数据。再次打开时先显示上次内容，再在后台更新；缓存按账号隔离。"
                )

                featureToggle(
                    title: "断点续播预热",
                    systemImage: "goforward",
                    isOn: Binding(
                        get: { libraryStore.resourceLoadingResumePacketWarmupEnabled },
                        set: { libraryStore.setResourceLoadingResumePacketWarmupEnabled($0) }
                    ),
                    detail: "从上次进度继续看时，多给目标片段一点准备时间，尝试减少恢复画面的等待。"
                )
            }

            Section {
                NavigationLink {
                    ResourceLoadingDiagnosticsView(libraryStore: libraryStore)
                } label: {
                    SettingsNavigationRow(
                        title: "资源加载诊断",
                        subtitle: "查看命中次数、耗时和最近加载事件",
                        systemImage: "chart.bar.xaxis"
                    )
                }
            } footer: {
                Text("资源加载调度已作为正式功能启用。这里的 5 个小功能仍可独立调整。诊断只记录统计数字和功能状态。")
            }
        }
        .tint(libraryStore.appTintColor)
        .formStyle(.grouped)
        .nativeTopScrollEdgeEffect()
        .hiddenInlineNavigationTitle()
    }

    private func featureToggle(
        title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        detail: String
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: systemImage)
                Text(detail)
                    .appTypography(.settingsSubtitle, fallback: .caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
