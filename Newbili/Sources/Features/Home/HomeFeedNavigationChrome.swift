import SwiftUI

struct HomeFeedNavigationChrome: ViewModifier {
    @Binding var primarySection: HomePrimarySection
    let onSelectSection: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let isModeSwitcherExperimentEnabled: Bool
    let onOpenAccountMessages: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isModeSwitcherExperimentEnabled {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    HomeNavigationModeControl(
                        selection: $primarySection,
                        onSelect: onSelectSection
                    )
                    .padding(.vertical, 7)
                    .background(HomeProgressiveNavigationBlur())
                }
                .rootNavigationTitle("首页") {
                    accountMessageButton
                }
                .nativeTopNavigationChrome()
        } else {
            content
                .rootNavigationTitle("首页") {
                    HomePrimarySectionMenu(
                        selection: primarySection,
                        onSelect: onSelectSection
                    )
                }
                .nativeTopNavigationChrome()
        }
    }

    @ViewBuilder
    private var accountMessageButton: some View {
        if let accountMessageViewModel {
            HomeAccountMessageButton(
                viewModel: accountMessageViewModel,
                action: onOpenAccountMessages
            )
        } else {
            HomeAccountMessageButtonContent(
                hasUnread: false,
                action: onOpenAccountMessages
            )
        }
    }

}

private struct HomeProgressiveNavigationBlur: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.92), location: 0.58),
                        .init(color: .black.opacity(0.42), location: 0.82),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    func homeFeedNavigationChrome(
        primarySection: Binding<HomePrimarySection>,
        onSelectSection: @escaping (HomePrimarySection) -> Void,
        accountMessageViewModel: AccountMessageCenterViewModel?,
        isModeSwitcherExperimentEnabled: Bool,
        onOpenAccountMessages: @escaping () -> Void
    ) -> some View {
        modifier(
            HomeFeedNavigationChrome(
                primarySection: primarySection,
                onSelectSection: onSelectSection,
                accountMessageViewModel: accountMessageViewModel,
                isModeSwitcherExperimentEnabled: isModeSwitcherExperimentEnabled,
                onOpenAccountMessages: onOpenAccountMessages
            )
        )
    }
}

private struct HomeNavigationModeControl: View {
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(HomePrimarySection.allCases) { section in
                    Button {
                        onSelect(section)
                    } label: {
                        Text(section.title)
                            .font(.subheadline.weight(selection == section ? .bold : .medium))
                            .foregroundStyle(selection == section ? .primary : .secondary)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background {
                                if selection == section {
                                    Capsule()
                                        .fill(.primary.opacity(0.10))
                                        .biliPlayerClearGlass(interactive: true, in: Capsule())
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .id(section)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
    }
}

private struct HomePrimarySectionMenu: View {
    let selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void

    var body: some View {
        Menu {
            ForEach(HomePrimarySection.allCases) { section in
                Button {
                    onSelect(section)
                } label: {
                    Label(
                        section.title,
                        systemImage: selection == section ? "checkmark" : section.systemImage
                    )
                }
            }
        } label: {
            Image(systemName: selection.systemImage)
                .frame(width: 34, height: 34)
        }
        .accessibilityLabel("首页内容")
        .accessibilityValue(selection.title)
    }
}

private struct HomeAccountMessageButton: View {
    @ObservedObject var viewModel: AccountMessageCenterViewModel
    let action: () -> Void

    var body: some View {
        HomeAccountMessageButtonContent(
            hasUnread: viewModel.hasUnreadMessages,
            action: action
        )
    }
}

private struct HomeAccountMessageButtonContent: View {
    @Environment(\.appThemeTintColor) private var appTintColor
    let hasUnread: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bell.fill")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: VideoDetailActionStrip.Metrics.iconSize, weight: .semibold))
                .foregroundStyle(hasUnread ? appTintColor : Color.primary)
                .frame(
                    width: VideoDetailActionStrip.Metrics.actionLabelSide,
                    height: VideoDetailActionStrip.Metrics.actionLabelSide
                )
                .contentShape(Circle())
        }
        .buttonBorderShape(.circle)
        .controlSize(.mini)
        .biliGlassButtonStyle()
        .frame(width: 34, height: 34)
        .contentShape(Circle())
        .accessibilityLabel("账号消息")
        .accessibilityValue(hasUnread ? "有未读消息" : "全部已读")
    }
}
