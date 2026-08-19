import SwiftUI

enum AccountLibraryKind: Hashable, Identifiable {
    case history
    case favorites

    var id: Self { self }

    var title: String {
        switch self {
        case .history:
            return "观看记录"
        case .favorites:
            return "账号收藏"
        }
    }

    var systemImage: String {
        switch self {
        case .history:
            return "clock.arrow.circlepath"
        case .favorites:
            return "star"
        }
    }

    var timestampTitle: String {
        switch self {
        case .history:
            return "最近观看"
        case .favorites:
            return "收藏时间"
        }
    }

    var emptyTitle: String {
        switch self {
        case .history:
            return "账号里还没有观看记录"
        case .favorites:
            return "账号收藏夹还没有内容"
        }
    }

    var loggedOutTitle: String {
        switch self {
        case .history:
            return "登录后同步账号观看记录"
        case .favorites:
            return "登录后同步账号收藏"
        }
    }

    var loadingTitle: String {
        switch self {
        case .history:
            return "正在同步观看记录"
        case .favorites:
            return "正在同步账号收藏"
        }
    }

    var errorTitle: String {
        switch self {
        case .history:
            return "观看记录同步失败"
        case .favorites:
            return "账号收藏同步失败"
        }
    }

    var loadMoreTitle: String {
        switch self {
        case .history:
            return "正在加载更多观看记录"
        case .favorites:
            return "正在加载更多收藏"
        }
    }

    var loadMoreErrorTitle: String {
        switch self {
        case .history:
            return "更多观看记录加载失败"
        case .favorites:
            return "更多收藏加载失败"
        }
    }
}

struct AccountLibraryButtonRow: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    let title: String
    let systemImage: String
    let badgeText: String?

    init(title: String, systemImage: String, badgeText: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.badgeText = badgeText
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(appTintColor)
                .frame(width: 28, height: 28)

            Text(title)
                .appTypography(.settingsRow, fallback: .subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let badgeText {
                Text(badgeText)
                    .appTypography(.badge, fallback: .caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(.red, in: Capsule())
                    .accessibilityLabel("\(badgeText) 条未读")
            }
        }
    }
}
