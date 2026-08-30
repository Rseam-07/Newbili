import SwiftUI

struct MineSettingsSearchItem: Identifiable {
    let route: MineOverlayRoute
    let title: String
    let subtitle: String
    let systemImage: String
    let keywords: [String]

    var id: String { title }

    func matches(_ normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }
        return ([title, subtitle] + keywords).contains {
            $0.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }
}

struct MineSettingsSearchView: View {
    @ObservedObject var libraryStore: LibraryStore
    @State private var query = ""

    static let searchableItems: [MineSettingsSearchItem] = [
        MineSettingsSearchItem(
            route: .interfaceSettings,
            title: "样式设置",
            subtitle: "主题、字号、底栏、帧率与图片显示",
            systemImage: "paintpalette",
            keywords: ["界面显示", "外观", "深色模式", "Liquid Glass", "液态玻璃", "Fluent", "Fluent UI", "重启生效", "iPad", "120Hz", "图标"]
        ),
        MineSettingsSearchItem(
            route: .homeAndSearchSettings,
            title: "推荐与搜索设置",
            subtitle: "推荐来源、首页风格、首页布局、刷新距离与热搜",
            systemImage: "sparkles",
            keywords: ["首页使用app端推荐", "web端推荐", "首页布局", "热门搜索", "影像杂志", "流光画报", "每日精选"]
        ),
        MineSettingsSearchItem(
            route: .playbackSettings,
            title: "视频与播放设置",
            subtitle: "画质、解码、详情内容、后台播放、画中画与听视频",
            systemImage: "video.badge.waveform",
            keywords: ["视频设置", "播放器设置", "倍速", "后台播放", "听视频", "画中画", "解码", "CDN", "启用点击弹幕", "弹幕交互"]
        ),
        MineSettingsSearchItem(
            route: .playbackSettings,
            title: "视频详情内容",
            subtitle: "相关视频、视频评论与简介默认展开",
            systemImage: "rectangle.stack.badge.play",
            keywords: ["视频页显示相关视频", "显示视频评论", "默认展开视频简介", "相关推荐", "评论入口", "视频简介"]
        ),
        MineSettingsSearchItem(
            route: .danmakuSettings,
            title: "弹幕设置",
            subtitle: "点击交互、显示区域、字号、描边、速度、行高与密度",
            systemImage: "text.bubble",
            keywords: ["弹幕", "启用点击弹幕", "点击弹幕悬停", "弹幕交互", "复制弹幕", "点赞弹幕", "举报弹幕", "滚动弹幕", "顶部弹幕", "底部弹幕", "透明度", "同屏数量", "屏蔽区域"]
        ),
        MineSettingsSearchItem(
            route: .contentFilterSettings,
            title: "内容与推荐过滤",
            subtitle: "广告、带货、动态关键词与推荐过滤器",
            systemImage: "line.3.horizontal.decrease.circle",
            keywords: ["内容过滤", "关键词", "最低播放量", "最短时长", "点赞率"]
        ),
        MineSettingsSearchItem(
            route: .privacySettings,
            title: "隐私设置",
            subtitle: "无痕、游客推荐与多账号用途分配",
            systemImage: "hand.raised",
            keywords: ["隐私", "无痕模式", "游客模式", "账号", "历史记录"]
        ),
        MineSettingsSearchItem(
            route: .appleIntelligenceSettings,
            title: "Siri 与 Apple Intelligence",
            subtitle: "系统快捷指令、语音打开页面与播放 BV 视频",
            systemImage: "apple.intelligence",
            keywords: ["Apple 智能", "Siri", "App Intents", "快捷指令", "Spotlight", "播放视频"]
        )
    ]

    private var results: [MineSettingsSearchItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.searchableItems.filter { $0.matches(normalizedQuery) }
    }

    var body: some View {
        List {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section(query.isEmpty ? "全部设置" : "搜索结果") {
                    ForEach(results) { item in
                        NavigationLink(value: item.route) {
                            SettingsNavigationRow(
                                title: item.title,
                                subtitle: item.subtitle,
                                systemImage: item.systemImage
                            )
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
        }
        .tint(libraryStore.appTintColor)
        .listStyle(.insetGrouped)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索播放器、弹幕、推荐、隐私等"
        )
        .navigationTitle("搜索设置")
        .navigationBarTitleDisplayMode(.inline)
        .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)
    }
}
