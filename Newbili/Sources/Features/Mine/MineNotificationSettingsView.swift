import SwiftUI

struct MineNotificationSettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject var libraryStore: LibraryStore

    private var service: UpdateNotificationService {
        dependencies.updateNotificationService
    }

    var body: some View {
        Form {
            Section {
                Picker("关注 UP 更新", selection: Binding(
                    get: { libraryStore.followedUploaderNotificationLevel },
                    set: { libraryStore.setFollowedUploaderNotificationLevel($0) }
                )) {
                    ForEach(FollowedUploaderNotificationLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.navigationLink)

                Text(libraryStore.followedUploaderNotificationLevel.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !sessionStore.isLoggedIn,
                   libraryStore.followedUploaderNotificationLevel != .off {
                    Label("登录后才能读取关注动态与特别关注列表。", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("关注 UP")
            } footer: {
                Text(UpdateNotificationCopy.backgroundDeliveryNotice)
            }

            Section("系统通知权限") {
                LabeledContent("当前状态", value: service.permissionState.title)

                switch service.permissionState {
                case .notDetermined:
                    Button {
                        Task { await service.requestPermissionFromUserAction() }
                    } label: {
                        Label("允许系统通知", systemImage: "bell.badge")
                    }
                case .denied:
                    Button(action: service.openSystemNotificationSettings) {
                        Label("前往系统设置开启", systemImage: "gear")
                    }
                case .enabled:
                    Button {
                        Task { _ = await service.refresh(reason: .manual) }
                    } label: {
                        if service.isRefreshing {
                            Label("正在检查更新", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("立即检查更新", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(service.isRefreshing || !service.hasAnyTrackingTarget)
                }

                Text(service.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink(value: MineOverlayRoute.markedAnime) {
                    LabeledContent {
                        Text("\(libraryStore.markedAnimeSnapshots.count) 项")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("我的追更", systemImage: "sparkles.tv")
                    }
                }
            } footer: {
                Text("在视频播放器的更多菜单中选择“标记为番剧”。Newbili 会保存标题、封面和分 P 快照；检测到新增分 P 后发送本地通知。")
            }
        }
        .tint(libraryStore.appTintColor)
        .navigationTitle("更新通知与追更")
        .navigationBarTitleDisplayMode(.inline)
        .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)
        .task {
            await service.refreshPermissionState()
        }
    }
}
