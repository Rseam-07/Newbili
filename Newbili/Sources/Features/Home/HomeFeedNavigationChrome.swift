import SwiftUI

struct HomeFeedNavigationChrome: ViewModifier {
    @Binding var primarySection: HomePrimarySection
    let onSelectSection: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let isModeSwitcherExperimentEnabled: Bool
    let prefersCinematicChrome: Bool
    let prefersEditorialChrome: Bool
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
                .modifier(
                    HomeCenteredNavigationChrome(
                        selection: $primarySection,
                        onSelect: onSelectSection,
                        accountMessageViewModel: accountMessageViewModel,
                        usesDarkAppearance: prefersEditorialChrome,
                        onOpenAccountMessages: onOpenAccountMessages
                    )
                )
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

}

private struct HomeCenteredNavigationChrome: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appInterfaceStyle) private var interfaceStyle
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let usesDarkAppearance: Bool
    let onOpenAccountMessages: () -> Void
    @State private var isCollapsed = false

    func body(content: Content) -> some View {
        content
            .environment(\.rootNavigationTitleHidden, $isCollapsed)
            .hiddenRootNavigationTitle("首页")
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isCollapsed {
                    Group {
                        if usesDarkAppearance {
                            HomeEditorialNavigationHeader(
                                selection: $selection,
                                onSelect: onSelect,
                                accountMessageViewModel: accountMessageViewModel,
                                onOpenAccountMessages: onOpenAccountMessages
                            )
                        } else {
                            HomeCenteredNavigationHeader(
                                selection: $selection,
                                onSelect: onSelect,
                                accountMessageViewModel: accountMessageViewModel,
                                usesDarkAppearance: false,
                                onOpenAccountMessages: onOpenAccountMessages
                            )
                        }
                    }
                    .transition(
                        reduceMotion || interfaceStyle.isFluent
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity)
                    )
                }
            }
            .animation(navigationAnimation, value: isCollapsed)
    }

    private var navigationAnimation: Animation? {
        guard !reduceMotion else { return nil }
        if interfaceStyle.isFluent {
            return AppMotion.topLevel(reduceMotion: false)
        }
        return .smooth(duration: 0.24)
    }
}

private struct HomeCenteredNavigationHeader: View {
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let usesDarkAppearance: Bool
    let onOpenAccountMessages: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HomeBrandMark()
                    .frame(width: 44, height: 44)
                    .biliGlassEffect(
                        tint: Color.accentColor.opacity(0.08),
                        interactive: false,
                        in: Circle()
                    )

                HomeNavigationModeControl(
                    selection: $selection,
                    onSelect: onSelect,
                    isCinematic: usesDarkAppearance,
                    isEditorial: false,
                    usesCompactTypography: true
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .frame(height: 44)
                .biliGlassEffect(
                    tint: usesDarkAppearance
                        ? .black.opacity(0.20)
                        : Color(.systemBackground).opacity(0.10),
                    interactive: false,
                    in: Capsule()
                )

                accountMessageButton
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 3)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private struct HomeBrandMark: View {
        var body: some View {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.96), Color.indigo.opacity(0.86)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)

                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .offset(x: 1)
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var accountMessageButton: some View {
        if let accountMessageViewModel {
            HomeAccountMessageButton(
                viewModel: accountMessageViewModel,
                isCinematic: usesDarkAppearance,
                action: onOpenAccountMessages
            )
        } else {
            HomeAccountMessageButtonContent(
                hasUnread: false,
                isCinematic: usesDarkAppearance,
                action: onOpenAccountMessages
            )
        }
    }
}

private struct HomeEditorialNavigationHeader: View {
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void

    var body: some View {
        ZStack {
            HomeNavigationModeControl(
                selection: $selection,
                onSelect: onSelect,
                isCinematic: true,
                isEditorial: true,
                usesCompactTypography: true
            )
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.horizontal, 54)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            HStack {
                HomeEditorialMark()
                    .frame(width: 44, height: 44)

                Spacer(minLength: 0)

                accountMessageButton
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 3)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(HomeEditorialPalette.background.opacity(0.98))
        .accessibilityElement(children: .contain)
    }

    private var accountMessageButton: some View {
        Group {
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
}

private struct HomeEditorialMark: View {
    var body: some View {
        ZStack {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)

            Circle()
                .fill(HomeEditorialPalette.accent)
                .frame(width: 6, height: 6)
                .offset(x: 13, y: -11)
        }
        .accessibilityLabel("Newbili 首页")
    }
}

struct HomeCinematicNavigationHeader: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void

    var body: some View {
        ZStack {
            HomeNavigationModeControl(
                selection: $selection,
                onSelect: onSelect,
                isCinematic: true,
                isEditorial: false,
                usesCompactTypography: false
            )
            .frame(width: HomeNavigationGeometricCenteringPolicy.navigationWidth)

            HStack(spacing: 0) {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(
                        width: HomeNavigationGeometricCenteringPolicy.sideSlotWidth,
                        height: HomeNavigationGeometricCenteringPolicy.sideSlotWidth
                    )
                    .accessibilityLabel("Newbili 首页")

                Spacer(minLength: 0)

                accountMessageButton
                    .frame(
                        width: HomeNavigationGeometricCenteringPolicy.sideSlotWidth,
                        height: HomeNavigationGeometricCenteringPolicy.sideSlotWidth
                    )
            }
            .frame(maxWidth: .infinity)
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

enum HomeNavigationGeometricCenteringPolicy {
    static let sideSlotWidth = BiliInteractiveTarget.minimumSide
    static let navigationWidth: CGFloat = 330
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

extension View {
    func homeFeedNavigationChrome(
        primarySection: Binding<HomePrimarySection>,
        onSelectSection: @escaping (HomePrimarySection) -> Void,
        accountMessageViewModel: AccountMessageCenterViewModel?,
        isModeSwitcherExperimentEnabled: Bool,
        prefersCinematicChrome: Bool = false,
        prefersEditorialChrome: Bool = false,
        onOpenAccountMessages: @escaping () -> Void
    ) -> some View {
        modifier(
            HomeFeedNavigationChrome(
                primarySection: primarySection,
                onSelectSection: onSelectSection,
                accountMessageViewModel: accountMessageViewModel,
                isModeSwitcherExperimentEnabled: isModeSwitcherExperimentEnabled,
                prefersCinematicChrome: prefersCinematicChrome,
                prefersEditorialChrome: prefersEditorialChrome,
                onOpenAccountMessages: onOpenAccountMessages
            )
        )
    }
}

private struct HomeNavigationModeControl: View {
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let isCinematic: Bool
    let isEditorial: Bool
    let usesCompactTypography: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(HomePrimarySection.allCases) { section in
                            Button {
                                onSelect(section)
                            } label: {
                                VStack(spacing: 0) {
                                    Text(section.title)
                                        .font(
                                            usesCompactTypography
                                                ? .caption.weight(selection == section ? .semibold : .regular)
                                                : .subheadline.weight(selection == section ? .semibold : .regular)
                                        )
                                        .foregroundStyle(foregroundStyle(for: section))
                                        .padding(.horizontal, usesCompactTypography ? 8 : 11)
                                        .frame(height: isEditorial ? 36 : 38)

                                    if isEditorial {
                                        Capsule()
                                            .fill(
                                                selection == section
                                                    ? HomeEditorialPalette.accent
                                                    : Color.clear
                                            )
                                            .frame(width: 18, height: 2)
                                    }
                                }
                                    .background {
                                        if selection == section, !isEditorial {
                                            Capsule()
                                                .fill(
                                                    isCinematic
                                                        ? .white.opacity(0.16)
                                                        : Color.accentColor.opacity(0.14)
                                                )
                                                .overlay {
                                                    if !isCinematic {
                                                        Capsule()
                                                            .strokeBorder(Color.accentColor.opacity(0.16), lineWidth: 0.5)
                                                    }
                                                }
                                        }
                                    }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(section)
                            .accessibilityAddTraits(selection == section ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 2)
                    .frame(minWidth: geometry.size.width, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selection, initial: true) { _, value in
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
        .frame(height: 44)
        .accessibilityElement(children: .contain)
    }

    private func foregroundStyle(for section: HomePrimarySection) -> Color {
        if isEditorial {
            return .white.opacity(selection == section ? 1 : 0.56)
        }
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
                .font(.system(size: HomeNavigationControlMetrics.iconSize, weight: .semibold))
                .foregroundStyle(hasUnread ? appTintColor : isCinematic ? Color.white : Color.primary)
                .frame(width: HomeNavigationControlMetrics.side, height: HomeNavigationControlMetrics.side)
                .contentShape(Circle())
        }
        .buttonBorderShape(.circle)
        .controlSize(.mini)
        .biliGlassButtonStyle()
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .accessibilityLabel("账号消息")
        .accessibilityValue(hasUnread ? "有未读消息" : "全部已读")
    }
}

private enum HomeNavigationControlMetrics {
    static let side: CGFloat = 44
    static let iconSize: CGFloat = 16
}
