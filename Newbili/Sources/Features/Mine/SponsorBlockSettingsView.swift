import SwiftUI

struct SponsorBlockSettingsView: View {
    @ObservedObject var libraryStore: LibraryStore

    var body: some View {
        Form {
            Section {
                Toggle("启用空降助手", isOn: enabledBinding)
                Toggle("显示跳过提示", isOn: showsSkipNoticeBinding)
                Toggle("发送匿名已跳过统计", isOn: trackingBinding)
            } header: {
                Text("基本设置")
            } footer: {
                Text("统计只向当前空降助手服务器报告片段已被跳过，不会上传账号 Cookie。")
            }

            Section {
                ForEach(SponsorBlockCategory.allCases) { category in
                    Picker(selection: behaviorBinding(for: category)) {
                        ForEach(SponsorBlockBehavior.allCases) { behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                    }
                    .pickerStyle(.navigationLink)
                }
            } header: {
                Text("分类处理方式")
            } footer: {
                Text("“每次播放跳过一次”会在同一次播放中保留回看机会；“始终自动跳过”在重新进入片段时仍会跳过；“手动决定”会在播放器上显示跳过按钮。")
            }

            Section {
                LabeledContent("最短片段") {
                    Text(minimumDurationTitle)
                        .foregroundStyle(.secondary)
                }

                Slider(value: minimumDurationBinding, in: 0...30, step: 1)
                    .accessibilityLabel("最短自动跳过片段")
            } header: {
                Text("片段长度")
            } footer: {
                Text("短于该时长的片段只会显示提示，不会自动跳过。设为 0 秒表示不限制。")
            }

            Section {
                TextField("https://www.bsbsb.top", text: customServerBinding)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                if !preferences.customServerURL.isEmpty, preferences.serverURL == nil {
                    Label("请输入有效的 HTTP 或 HTTPS 地址", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("自定义服务器")
            } footer: {
                Text("留空时使用 Newbili 默认服务器。修改后会在下一次载入视频片段时生效。")
            }

            Section {
                Button("恢复默认设置", role: .destructive) {
                    withAnimation(.smooth(duration: 0.24)) {
                        libraryStore.setSponsorBlockPreferences(.default)
                    }
                }
            }
        }
        .navigationTitle("空降助手")
        .navigationBarTitleDisplayMode(.inline)
        .tint(libraryStore.appTintColor)
        .nativeTopScrollEdgeEffect()
    }

    private var preferences: SponsorBlockPreferences {
        libraryStore.sponsorBlockPreferences
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { libraryStore.sponsorBlockEnabled },
            set: { libraryStore.setSponsorBlockEnabled($0) }
        )
    }

    private var showsSkipNoticeBinding: Binding<Bool> {
        preferenceBinding(\.showsSkipNotice)
    }

    private var trackingBinding: Binding<Bool> {
        preferenceBinding(\.trackingEnabled)
    }

    private var minimumDurationBinding: Binding<Double> {
        preferenceBinding(\.minimumSegmentDuration)
    }

    private var customServerBinding: Binding<String> {
        preferenceBinding(\.customServerURL)
    }

    private func behaviorBinding(for category: SponsorBlockCategory) -> Binding<SponsorBlockBehavior> {
        Binding(
            get: { preferences.behavior(for: category.rawValue) },
            set: { libraryStore.setSponsorBlockBehavior($0, for: category) }
        )
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<SponsorBlockPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { value in
                var updated = preferences
                updated[keyPath: keyPath] = value
                libraryStore.setSponsorBlockPreferences(updated)
            }
        )
    }

    private var minimumDurationTitle: String {
        let seconds = Int(preferences.minimumSegmentDuration.rounded())
        return seconds == 0 ? "不限制" : "\(seconds) 秒"
    }
}
