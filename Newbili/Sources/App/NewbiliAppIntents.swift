import AppIntents
import Foundation

protocol NewbiliFixedRouteIntent: AppIntent {
    static var route: AppIntentRoute { get }
}

extension NewbiliFixedRouteIntent {
    static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    static var authenticationPolicy: IntentAuthenticationPolicy {
        .alwaysAllowed
    }

    func perform() async throws -> some IntentResult {
        AppIntentRouteInbox.shared.enqueue(Self.route)
        return .result()
    }
}

struct OpenNewbiliHomeIntent: NewbiliFixedRouteIntent {
    static let title: LocalizedStringResource = "打开 Newbili 首页"
    static let description = IntentDescription("打开 Newbili 并回到首页。")
    static let route = AppIntentRoute.home

    init() {}
}

struct OpenNewbiliHistoryIntent: NewbiliFixedRouteIntent {
    static let title: LocalizedStringResource = "打开观看记录"
    static let description = IntentDescription("在 Newbili 中打开账号的观看记录。")
    static let route = AppIntentRoute.history

    init() {}
}

struct OpenNewbiliWatchLaterIntent: NewbiliFixedRouteIntent {
    static let title: LocalizedStringResource = "打开稍后再看"
    static let description = IntentDescription("在 Newbili 中打开稍后再看列表。")
    static let route = AppIntentRoute.watchLater

    init() {}
}

struct OpenNewbiliFavoritesIntent: NewbiliFixedRouteIntent {
    static let title: LocalizedStringResource = "打开收藏"
    static let description = IntentDescription("在 Newbili 中打开收藏夹。")
    static let route = AppIntentRoute.favorites

    init() {}
}

struct PlayBilibiliVideoIntent: AppIntent {
    static let title: LocalizedStringResource = "播放 B 站视频"
    static let description = IntentDescription("使用 BV 号在 Newbili 中打开并播放指定视频。")
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    @Parameter(
        title: "BV 号",
        description: "可以输入 BV 号或包含 BV 号的 bilibili.com 视频链接。",
        inputOptions: String.IntentInputOptions(
            capitalizationType: .none,
            multiline: false
        )
    )
    var bvid: String

    static var parameterSummary: some ParameterSummary {
        Summary("播放 \(\.$bvid)")
    }

    init() {
        bvid = ""
    }

    init(bvid: String) {
        self.bvid = bvid
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let normalizedBVID = AppIntentVideoIdentifier.normalizedBVID(from: bvid) else {
            return .result(dialog: "没有识别到有效的 BV 号，请检查后重试。")
        }

        await AppIntentRouteInbox.shared.enqueue(.video(bvid: normalizedBVID))
        return .result(dialog: "正在用 Newbili 打开 \(normalizedBVID)。")
    }
}

struct NewbiliAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenNewbiliHomeIntent(),
            phrases: [
                "打开 \(.applicationName) 首页",
                "用 \(.applicationName) 看视频"
            ],
            shortTitle: "打开首页",
            systemImageName: "house"
        )
        AppShortcut(
            intent: OpenNewbiliHistoryIntent(),
            phrases: [
                "打开 \(.applicationName) 观看记录",
                "在 \(.applicationName) 看我的历史"
            ],
            shortTitle: "观看记录",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: OpenNewbiliWatchLaterIntent(),
            phrases: [
                "打开 \(.applicationName) 稍后再看",
                "在 \(.applicationName) 看稍后再看"
            ],
            shortTitle: "稍后再看",
            systemImageName: "clock.badge.checkmark"
        )
        AppShortcut(
            intent: OpenNewbiliFavoritesIntent(),
            phrases: [
                "打开 \(.applicationName) 收藏",
                "在 \(.applicationName) 看我的收藏"
            ],
            shortTitle: "收藏",
            systemImageName: "star"
        )
        AppShortcut(
            intent: PlayBilibiliVideoIntent(),
            phrases: [
                "用 \(.applicationName) 播放 B 站视频",
                "在 \(.applicationName) 打开 BV 视频"
            ],
            shortTitle: "播放 BV 视频",
            systemImageName: "play.rectangle"
        )
    }

    static var shortcutTileColor: ShortcutTileColor {
        .pink
    }
}
