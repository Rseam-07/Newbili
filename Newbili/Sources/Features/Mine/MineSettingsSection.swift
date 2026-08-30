import SwiftUI

struct MineSettingsSection: View {
    @ObservedObject var libraryStore: LibraryStore
    let onOpenRoute: (MineOverlayRoute) -> Void

    var body: some View {
        Section("设置") {
            MineOverlayNavigationButton {
                onOpenRoute(.settingsSearch)
            } label: {
                SettingsNavigationRow(
                    title: "搜索设置",
                    subtitle: "按 PiliPlus 常用名称查找设置与功能",
                    systemImage: "magnifyingglass"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.interfaceSettings)
            } label: {
                SettingsNavigationRow(
                    title: "样式设置",
                    subtitle: interfaceSettingsSummary,
                    systemImage: "paintpalette"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.homeAndSearchSettings)
            } label: {
                SettingsNavigationRow(
                    title: "推荐与搜索设置",
                    subtitle: homeAndSearchSummary,
                    systemImage: "sparkles"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.playbackSettings)
            } label: {
                SettingsNavigationRow(
                    title: "视频与播放设置",
                    subtitle: playbackSettingsSummary,
                    systemImage: "video.badge.waveform"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.contentFilterSettings)
            } label: {
                SettingsNavigationRow(
                    title: "内容过滤",
                    subtitle: contentFilterSummary,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.privacySettings)
            } label: {
                SettingsNavigationRow(
                    title: "隐私设置",
                    subtitle: privacySummary,
                    systemImage: "hand.raised"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.appleIntelligenceSettings)
            } label: {
                SettingsNavigationRow(
                    title: "Siri 与 Apple Intelligence",
                    subtitle: "Siri/快捷指令已接入 · \(AppleIntelligenceAvailabilityService.current().title)",
                    systemImage: "apple.intelligence"
                )
            }

        }
    }

    private var interfaceSettingsSummary: String {
        let tabs = libraryStore.visibleRootTabs
            .filter(\.participatesInRootTabVisibilitySettings)
            .map(\.title)
            .joined(separator: "、")
        return "\(libraryStore.appearanceMode.title) · \(tabs)"
    }

    private var homeAndSearchSummary: String {
        let hotSearch = libraryStore.showsHotSearches ? "热搜开启" : "热搜关闭"
        return "\(libraryStore.homePresentationStyle.title) · \(libraryStore.homeFeedLayout.title) · \(libraryStore.homeRecommendFeedSourcePreference.title) · \(hotSearch)"
    }

    private var privacySummary: String {
        var enabled = [String]()
        if libraryStore.incognitoModeEnabled {
            enabled.append("无痕")
        }
        if libraryStore.guestModeEnabled {
            enabled.append("游客")
        }
        return enabled.isEmpty ? "默认" : enabled.joined(separator: "、")
    }

    private var contentFilterSummary: String {
        var parts = ["动态 \(libraryStore.blockedDynamicKeywords.count) 个关键词"]
        if libraryStore.videoRecommendationFilterConfiguration.isActive {
            parts.append("推荐过滤开启")
        }
        return parts.joined(separator: "，")
    }

    private var playbackSettingsSummary: String {
        var parts = [
            libraryStore.playbackAutoOptimizationMode.title,
            libraryStore.videoDetailAutoplayEnabled ? "详情自动播放" : "详情手动播放",
            "后台\(libraryStore.backgroundPlaybackMode.title)",
            libraryStore.videoCodecPreference.title,
            libraryStore.dolbyVisionRenderingPolicy.title
        ]
        if libraryStore.forceHardwareDecodeEnabled {
            parts.append("硬解优先")
        }
        return parts.joined(separator: " · ")
    }
}
