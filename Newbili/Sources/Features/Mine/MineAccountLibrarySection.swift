import SwiftUI

struct MineAccountLibrarySection: View {
    @ObservedObject var accountMessageViewModel: AccountMessageCenterViewModel
    @ObservedObject var libraryStore: LibraryStore
    let isLoggedIn: Bool
    let onOpenRoute: (MineOverlayRoute) -> Void

    var body: some View {
        Section {
            if isLoggedIn {
                MineOverlayNavigationButton {
                    onOpenRoute(.accountMessages)
                } label: {
                    AccountLibraryButtonRow(
                        title: "账号消息",
                        systemImage: "bell.badge",
                        badgeText: accountMessageViewModel.totalUnreadBadgeText
                    )
                }
            }

            MineOverlayNavigationButton {
                onOpenRoute(.history)
            } label: {
                AccountLibraryButtonRow(
                    title: "观看记录",
                    systemImage: "clock.arrow.circlepath"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.favorites)
            } label: {
                AccountLibraryButtonRow(
                    title: "账号收藏",
                    systemImage: "star"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.watchLater)
            } label: {
                AccountLibraryButtonRow(
                    title: "稍后再看",
                    systemImage: "bookmark"
                )
            }

            MineOverlayNavigationButton {
                onOpenRoute(.markedAnime)
            } label: {
                AccountLibraryButtonRow(
                    title: "我的追更",
                    systemImage: "sparkles.tv",
                    badgeText: libraryStore.markedAnimeSnapshots.isEmpty
                        ? nil
                        : String(libraryStore.markedAnimeSnapshots.count),
                    badgeAccessibilityLabel: libraryStore.markedAnimeSnapshots.isEmpty
                        ? nil
                        : UpdateNotificationAccessibilityText.markedAnimeCount(
                            libraryStore.markedAnimeSnapshots.count
                        )
                )
            }
        } header: {
            Text("账号内容")
        }
    }
}
