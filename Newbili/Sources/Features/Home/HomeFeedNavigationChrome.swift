import SwiftUI

struct HomeFeedNavigationChrome: ViewModifier {
    @Binding var primarySection: HomePrimarySection
    let onSelectSection: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let isModeSwitcherExperimentEnabled: Bool
    let prefersCinematicChrome: Bool
    let onOpenAccountMessages: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        resolvedBody(
            content: content,
            usesCinematicChrome: prefersCinematicChrome
        )
    }

    @ViewBuilder
    private func resolvedBody(content: Content, usesCinematicChrome: Bool) -> some View {
        if isModeSwitcherExperimentEnabled, usesCinematicChrome {
            content
                .hiddenRootNavigationTitle("首页")
        } else if isModeSwitcherExperimentEnabled {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    HomeNavigationModeControl(
                        selection: $primarySection,
                        onSelect: onSelectSection,
                        isCinematic: false
                    )
                    .padding(.vertical, 7)
                    .background(HomeProgressiveNavigationBlur())
                }
                .rootNavigationTitle("首页") {
                    accountMessageButton(isCinematic: false)
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
    private func accountMessageButton(isCinematic: Bool) -> some View {
        if let accountMessageViewModel {
            HomeAccountMessageButton(
                viewModel: accountMessageViewModel,
                isCinematic: isCinematic,
                action: onOpenAccountMessages
            )
        } else {
            HomeAccountMessageButtonContent(
                hasUnread: false,
                isCinematic: isCinematic,
                action: onOpenAccountMessages
            )
        }
    }

}

struct HomeCinematicNavigationHeader: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .accessibilityLabel("Newbili 首页")

            HomeNavigationModeControl(
                selection: $selection,
                onSelect: onSelect,
                isCinematic: true
            )
            .frame(width: 330, alignment: .leading)

            Spacer(minLength: 10)
            accountMessageButton
        }
        .safeAreaPadding(.horizontal, 18)
        .padding(.top, verticalSizeClass == .compact ? 18 : 12)
        .padding(.bottom, 34)
        .background(HomeCinematicNavigationScrim())
    }

    @ViewBuilder
    private var accountMessageButton: some View {
        if let accountMessageViewModel {
            HomeAccountMessageButton(
                viewModel: accountMessageViewModel,
                isCinematic: true,
                action: onOpenAccountMessages
            )
        } else {
            HomeAccountMessageButtonContent(
                hasUnread: false,
                isCinematic: true,
                action: onOpenAccountMessages
            )
        }
    }
}

private struct HomeCinematicNavigationScrim: View {
    var body: some View {
        LinearGradient(
            colors: [.black.opacity(0.72), .black.opacity(0.34), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
        prefersCinematicChrome: Bool = false,
        onOpenAccountMessages: @escaping () -> Void
    ) -> some View {
        modifier(
            HomeFeedNavigationChrome(
                primarySection: primarySection,
                onSelectSection: onSelectSection,
                accountMessageViewModel: accountMessageViewModel,
                isModeSwitcherExperimentEnabled: isModeSwitcherExperimentEnabled,
                prefersCinematicChrome: prefersCinematicChrome,
                onOpenAccountMessages: onOpenAccountMessages
            )
        )
    }
}

private struct HomeNavigationModeControl: View {
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let isCinematic: Bool

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(HomePrimarySection.allCases) { section in
                    Button {
                        onSelect(section)
                    } label: {
                        Text(section.title)
                            .font(.subheadline.weight(selection == section ? .bold : .medium))
                            .foregroundStyle(foregroundStyle(for: section))
                            .padding(.horizontal, 11)
                            .frame(height: isCinematic ? 34 : 30)
                            .background {
                                if selection == section {
                                    Capsule()
                                        .fill(isCinematic ? .white.opacity(0.16) : .primary.opacity(0.10))
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

    private func foregroundStyle(for section: HomePrimarySection) -> Color {
        if isCinematic {
            return .white.opacity(selection == section ? 1 : 0.66)
        }
        return selection == section ? .primary : .secondary
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
    let isCinematic: Bool
    let action: () -> Void

    var body: some View {
        HomeAccountMessageButtonContent(
            hasUnread: viewModel.hasUnreadMessages,
            isCinematic: isCinematic,
            action: action
        )
    }
}

private struct HomeAccountMessageButtonContent: View {
    @Environment(\.appThemeTintColor) private var appTintColor
    let hasUnread: Bool
    var isCinematic = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bell.fill")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: VideoDetailActionStrip.Metrics.iconSize, weight: .semibold))
                .foregroundStyle(hasUnread ? appTintColor : isCinematic ? Color.white : Color.primary)
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
