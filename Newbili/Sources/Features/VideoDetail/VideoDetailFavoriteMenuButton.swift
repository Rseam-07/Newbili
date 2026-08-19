import SwiftUI

struct VideoDetailFavoriteMenuButton: View {
    let isFavorited: Bool
    let canFavorite: Bool
    let isDisabled: Bool
    let tintColor: Color
    let favorite: () -> Void
    let watchLater: () -> Void

    var body: some View {
        if canFavorite {
            Menu {
                Button(action: favorite) {
                    Label(isFavorited ? "管理收藏夹" : "收藏", systemImage: "star")
                }
                Button(action: watchLater) {
                    Label("加入稍后再看", systemImage: "bookmark")
                }
            } label: {
                VideoDetailActionStripIconLabel(
                    systemImage: "star.fill",
                    foregroundStyle: isFavorited ? tintColor : .primary
                )
            } primaryAction: {
                favorite()
            }
            .buttonBorderShape(.circle)
            .controlSize(.mini)
            .biliGlassButtonStyle()
            .contentShape(Circle())
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.52 : 1)
            .accessibilityLabel(isFavorited ? "已收藏，长按可加入稍后再看" : "收藏，长按可加入稍后再看")
        } else {
            Menu {
                Button(action: watchLater) {
                    Label("加入稍后再看", systemImage: "bookmark")
                }
            } label: {
                VideoDetailActionStripIconLabel(
                    systemImage: "bookmark.fill",
                    foregroundStyle: .primary
                )
            }
            .buttonBorderShape(.circle)
            .controlSize(.mini)
            .biliGlassButtonStyle()
            .contentShape(Circle())
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.52 : 1)
            .accessibilityLabel("加入稍后再看")
        }
    }
}
