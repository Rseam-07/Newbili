import SwiftUI

struct DanmakuSettingsTypeFilterSection: View {
    @Binding var settings: DanmakuSettings

    var body: some View {
        Section {
            Toggle("滚动弹幕", isOn: $settings.showsScrollingDanmaku)
            Toggle("顶部弹幕", isOn: $settings.showsTopDanmaku)
            Toggle("底部弹幕", isOn: $settings.showsBottomDanmaku)
        } header: {
            Text("显示类型")
        } footer: {
            Text("关闭某一类型后，视频与直播播放器都会立即隐藏它。")
        }
    }
}

struct DanmakuSettingsFilterRulesSection: View {
    @Binding var settings: DanmakuSettings

    var body: some View {
        Section {
            NavigationLink {
                DanmakuFilterRulesEditorView(settings: $settings)
            } label: {
                HStack(spacing: 12) {
                    Label("弹幕屏蔽", systemImage: "line.3.horizontal.decrease.circle")
                    Spacer(minLength: 8)
                    Text(ruleCount == 0 ? "未设置" : "\(ruleCount) 条")
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("支持关键词、正则表达式和用户 UID；规则仅在弹幕批次变化时匹配，不占用逐帧渲染时间。")
        }
    }

    private var ruleCount: Int {
        settings.blockedKeywords.count
            + settings.blockedRegularExpressions.count
            + settings.blockedUserIDs.count
    }
}

private enum DanmakuFilterRuleKind: String, CaseIterable, Identifiable {
    case keyword
    case regularExpression
    case userID

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyword: "关键词"
        case .regularExpression: "正则"
        case .userID: "用户 UID"
        }
    }

    var emptyText: String {
        switch self {
        case .keyword: "包含关键词的弹幕会被隐藏"
        case .regularExpression: "匹配正则表达式的弹幕会被隐藏"
        case .userID: "该用户的视频和直播弹幕会被隐藏"
        }
    }

    var prompt: String {
        switch self {
        case .keyword: "输入要屏蔽的关键词"
        case .regularExpression: "输入正则表达式，无需包含头尾 /"
        case .userID: "输入数字 UID"
        }
    }

    func values(in settings: DanmakuSettings) -> [String] {
        switch self {
        case .keyword: settings.blockedKeywords
        case .regularExpression: settings.blockedRegularExpressions
        case .userID: settings.blockedUserIDs
        }
    }

    func replaceValues(_ values: [String], in settings: inout DanmakuSettings) {
        switch self {
        case .keyword: settings.blockedKeywords = values
        case .regularExpression: settings.blockedRegularExpressions = values
        case .userID: settings.blockedUserIDs = values
        }
    }
}

private struct DanmakuFilterRulesEditorView: View {
    @Binding var settings: DanmakuSettings
    @State private var selectedKind = DanmakuFilterRuleKind.keyword
    @State private var isPresentingRuleEditor = false

    var body: some View {
        List {
            Picker("规则类型", selection: $selectedKind) {
                ForEach(DanmakuFilterRuleKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            Section {
                if selectedRules.isEmpty {
                    ContentUnavailableView(
                        "暂无\(selectedKind.title)规则",
                        systemImage: "checkmark.shield",
                        description: Text(selectedKind.emptyText)
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(selectedRules.enumerated()), id: \.offset) { index, rule in
                        HStack(spacing: 12) {
                            Image(systemName: selectedKind == .userID ? "person.crop.circle.badge.xmark" : "text.badge.xmark")
                                .foregroundStyle(.secondary)
                            Text(rule)
                                .font(.body.monospaced(selectedKind == .regularExpression))
                                .textSelection(.enabled)
                            Spacer(minLength: 8)
                            Button(role: .destructive) {
                                removeRule(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("删除规则 \(rule)")
                        }
                    }
                }
            } header: {
                Text("\(selectedKind.title)（\(selectedRules.count)）")
            }
        }
        .navigationTitle("弹幕屏蔽")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                isPresentingRuleEditor = true
            } label: {
                Label("添加\(selectedKind.title)规则", systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(isPresented: $isPresentingRuleEditor) {
            DanmakuFilterRuleEditorSheet(
                kind: selectedKind,
                existingRules: Set(selectedRules)
            ) { rule in
                addRule(rule)
            }
            .presentationDetents([.medium])
        }
    }

    private var selectedRules: [String] {
        selectedKind.values(in: settings)
    }

    private func addRule(_ rule: String) {
        var updatedSettings = settings
        var values = selectedKind.values(in: updatedSettings)
        values.append(rule)
        selectedKind.replaceValues(values, in: &updatedSettings)
        settings = updatedSettings.normalized
    }

    private func removeRule(at index: Int) {
        var updatedSettings = settings
        var values = selectedKind.values(in: updatedSettings)
        guard values.indices.contains(index) else { return }
        values.remove(at: index)
        selectedKind.replaceValues(values, in: &updatedSettings)
        settings = updatedSettings.normalized
    }
}

private struct DanmakuFilterRuleEditorSheet: View {
    let kind: DanmakuFilterRuleKind
    let existingRules: Set<String>
    let save: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rule = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind.prompt, text: $rule)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(kind == .userID ? .numberPad : .default)
                } footer: {
                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Text(kind.emptyText)
                    }
                }
            }
            .navigationTitle("添加\(kind.title)规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        save(normalizedRule)
                        dismiss()
                    }
                    .disabled(validationMessage != nil)
                }
            }
        }
    }

    private var normalizedRule: String {
        rule.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validationMessage: String? {
        guard !normalizedRule.isEmpty else { return "内容不能为空" }
        guard existingRules.count < 100 else { return "此类规则已达到 100 条上限" }
        guard !existingRules.contains(normalizedRule) else { return "相同规则已经存在" }
        switch kind {
        case .keyword:
            return normalizedRule.count <= 80 ? nil : "关键词不能超过 80 个字符"
        case .regularExpression:
            guard normalizedRule.count <= 256 else { return "正则不能超过 256 个字符" }
            return DanmakuItemFilter.isValidRegularExpression(normalizedRule)
                ? nil
                : "正则表达式无效，请检查括号和转义符"
        case .userID:
            guard normalizedRule.count <= 20 else { return "UID 长度不正确" }
            return normalizedRule.allSatisfy { "0123456789".contains($0) } && normalizedRule != "0"
                ? nil
                : "UID 只能包含数字且不能为 0"
        }
    }
}

private extension Font {
    func monospaced(_ enabled: Bool) -> Font {
        enabled ? monospaced() : self
    }
}
