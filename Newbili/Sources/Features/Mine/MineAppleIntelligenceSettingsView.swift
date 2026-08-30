import SwiftUI

struct MineAppleIntelligenceSettingsView: View {
    @ObservedObject var libraryStore: LibraryStore

    private var availability: AppleIntelligenceAvailability {
        AppleIntelligenceAvailabilityService.current()
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    "启用设备端视频总结",
                    isOn: Binding(
                        get: { libraryStore.videoIntelligenceSummaryEnabled },
                        set: libraryStore.setVideoIntelligenceSummaryEnabled
                    )
                )
            } footer: {
                Text("开启后，展开视频简介时才会读取可用字幕并显示本地总结入口；关闭时不会发起字幕请求。")
            }

            Section {
                LabeledContent {
                    Text("已接入")
                        .foregroundStyle(Color.green)
                } label: {
                    Label("Siri 与快捷指令", systemImage: "mic")
                }

                LabeledContent {
                    Text(availability.title)
                        .foregroundStyle(availability.isAvailable ? Color.green : Color.secondary)
                } label: {
                    Label("设备端生成模型", systemImage: "apple.intelligence")
                }

                Text("Siri、快捷指令与 Spotlight 入口不依赖设备端生成模型；Apple Intelligence 模型能否使用，则由设备、系统语言和模型下载状态共同决定。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("系统智能")
            }

            Section("可用操作") {
                AppleIntelligenceActionRow(
                    title: "打开首页",
                    detail: "回到 Newbili 首页并清理旧导航状态",
                    systemImage: "house"
                )
                AppleIntelligenceActionRow(
                    title: "打开观看记录、稍后再看或收藏",
                    detail: "直接进入对应账号内容页",
                    systemImage: "rectangle.stack"
                )
                AppleIntelligenceActionRow(
                    title: "播放 BV 视频",
                    detail: "可向 Siri 或快捷指令提供 BV 号或 B 站视频链接",
                    systemImage: "play.rectangle"
                )
                AppleIntelligenceActionRow(
                    title: "设备端视频总结",
                    detail: summaryAvailabilityDetail,
                    systemImage: "apple.intelligence"
                )
            }

            Section {
                Text("Siri 与快捷指令只负责理解意图并导航，登录状态、网络错误和播放失败仍由原有页面处理，不会绕过权限检查，也不会复制一套播放器。视频总结会从 B站读取可用字幕，但总结本身仅使用设备端系统模型；模型不可用时不会改用远程服务，也不会把字幕提交给云端模型。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(libraryStore.appTintColor)
        .formStyle(.grouped)
        .navigationTitle("Siri 与 Apple Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)
    }

    private var summaryAvailabilityDetail: String {
        guard libraryStore.videoIntelligenceSummaryEnabled else {
            return "已关闭；可在本页主动开启"
        }
        return availability.isAvailable
            ? "优先读取 B站字幕并在本地总结；无字幕时明确降级为简介导读"
            : "保持开启后，模型可用时会出现在展开的视频信息下方"
    }
}

private struct AppleIntelligenceActionRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 44)
    }
}
