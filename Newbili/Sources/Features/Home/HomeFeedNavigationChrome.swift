import SwiftUI

struct HomeFeedNavigationChrome: ViewModifier {
    @Binding var primarySection: HomePrimarySection
    let onSelectSection: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let isModeSwitcherExperimentEnabled: Bool
    let prefersCinematicChrome: Bool
    let onOpenAccountMessages: () -> Void
    @State private var isHeaderCollapsed = false

    @ViewBuilder
    func body(content: Content) -> some View {
        resolvedBody(
            content: content,
            usesCinematicChrome: prefersCinematicChrome
        )
        .onChange(of: primarySection) { _, _ in
            isHeaderCollapsed = false
        }
        .onChange(of: prefersCinematicChrome) { _, _ in
            isHeaderCollapsed = false
        }
    }

    @ViewBuilder
    private func resolvedBody(content: Content, usesCinematicChrome: Bool) -> some View {
        if isModeSwitcherExperimentEnabled, usesCinematicChrome {
            content
                .hiddenRootNavigationTitle("首页")
        } else if isModeSwitcherExperimentEnabled {
            content
                .hiddenRootNavigationTitle("首页")
                .safeAreaInset(edge: .top, spacing: 0) {
                    HomeAdaptiveNavigationHeader(
                        selection: $primarySection,
                        onSelect: onSelectSection,
                        accountMessageViewModel: accountMessageViewModel,
                        onOpenAccountMessages: onOpenAccountMessages
                    )
                }
                .environment(\.rootNavigationTitleHidden, $isHeaderCollapsed)
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

struct HomeCinematicNavigationHeader: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var sessionStore: SessionStore
    @Binding var selection: HomePrimarySection
    let containerWidth: CGFloat
    let onSelect: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void

    var body: some View {
        Group {
            if !HomeNavigationHeaderLayoutPolicy.usesStackedLayout(
                containerWidth: containerWidth,
                usesAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            ) {
                ZStack {
                    HomeNavigationModeControl(
                        selection: $selection,
                        onSelect: onSelect,
                        isCinematic: true
                    )
                    .frame(width: HomeNavigationHeaderLayoutPolicy.centerControlWidth)

                    HStack(spacing: 14) {
                        cinematicGreeting
                            .frame(
                                width: wideSideSlotWidth,
                                alignment: .leading
                            )
                        Spacer(minLength: HomeNavigationHeaderLayoutPolicy.centerControlWidth)
                        accountMessageButton
                            .frame(width: wideSideSlotWidth, alignment: .trailing)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        cinematicGreeting
                        Spacer(minLength: 12)
                        accountMessageButton
                    }

                    HomeNavigationModeControl(
                        selection: $selection,
                        onSelect: onSelect,
                        isCinematic: true
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .safeAreaPadding(.horizontal, 18)
        .padding(.top, verticalSizeClass == .compact ? 18 : 12)
        .padding(.bottom, 34)
        .background(HomeCinematicNavigationScrim())
    }

    private var cinematicGreeting: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            HomeGreetingLabel(
                displayName: sessionStore.user?.uname,
                isCinematic: true,
                showsSubtitle: verticalSizeClass != .compact
            )
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    private var accountMessageButton: some View {
        HomeAccountMessageButtonHost(
            viewModel: accountMessageViewModel,
            isCinematic: true,
            action: onOpenAccountMessages
        )
    }

    private var wideSideSlotWidth: CGFloat {
        HomeNavigationHeaderLayoutPolicy.sideSlotWidth(containerWidth: containerWidth)
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

private struct HomeAdaptiveNavigationHeader: View {
    @Environment(\.rootNavigationTitleHidden) private var rootNavigationTitleHidden
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let onOpenAccountMessages: () -> Void

    var body: some View {
        Group {
            if !rootNavigationTitleHidden.wrappedValue {
                VStack(spacing: 7) {
                    HStack(spacing: 12) {
                        HomeGreetingLabel(
                            displayName: sessionStore.user?.uname,
                            isCinematic: false,
                            showsSubtitle: verticalSizeClass != .compact
                        )

                        Spacer(minLength: 12)
                        accountMessageButton
                    }

                    HomeNavigationModeControl(
                        selection: $selection,
                        onSelect: onSelect,
                        isCinematic: false
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .safeAreaPadding(.horizontal, 16)
                .padding(.top, verticalSizeClass == .compact ? 2 : 5)
                .padding(.bottom, 9)
                .background {
                    if reduceTransparency {
                        Color(.systemBackground)
                    } else {
                        HomeNavigationBackdrop()
                    }
                }
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .top).combined(with: .opacity)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    private var accountMessageButton: some View {
        HomeAccountMessageButtonHost(
            viewModel: accountMessageViewModel,
            isCinematic: false,
            action: onOpenAccountMessages
        )
    }
}

private struct HomeNavigationBackdrop: View {
    @Environment(\.appThemeTintColor) private var appTintColor

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0.98),
                    Color(.systemBackground).opacity(0.82),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [appTintColor.opacity(0.14), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 240
            )
        }
        .mask {
            LinearGradient(
                colors: [.black, .black, .black.opacity(0.82), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HomeGreetingLabel: View {
    let displayName: String?
    let isCinematic: Bool
    let showsSubtitle: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15 * 60)) { context in
            let greeting = HomeGreetingContent.make(
                date: context.date,
                displayName: displayName
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isCinematic ? Color.white : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if showsSubtitle {
                    Text(greeting.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isCinematic ? Color.white.opacity(0.66) : Color.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
        }
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
    @Environment(\.appThemeTintColor) private var appTintColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: HomePrimarySection
    let onSelect: (HomePrimarySection) -> Void
    let isCinematic: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            modeItems

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    modeItems
                        .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selection, initial: true) { _, newSelection in
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
                        proxy.scrollTo(newSelection, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.selection, trigger: selection)
        .animation(
            reduceMotion ? .easeOut(duration: 0.10) : .spring(response: 0.32, dampingFraction: 0.90),
            value: selection
        )
    }

    private var modeItems: some View {
        HStack(spacing: 3) {
            ForEach(HomePrimarySection.allCases) { section in
                Button {
                    onSelect(section)
                } label: {
                    Text(section.title)
                        .font(.subheadline.weight(selection == section ? .bold : .medium))
                        .foregroundStyle(foregroundStyle(for: section))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background {
                            if selection == section {
                                Capsule()
                                    .fill(selectionFill)
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(selectionStroke, lineWidth: 0.7)
                                    }
                                    .shadow(
                                        color: isCinematic ? .black.opacity(0.16) : appTintColor.opacity(0.10),
                                        radius: 7,
                                        y: 2
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(HomeNavigationButtonStyle())
                .id(section)
            }
        }
    }

    private func foregroundStyle(for section: HomePrimarySection) -> Color {
        if isCinematic {
            return .white.opacity(selection == section ? 1 : 0.66)
        }
        return selection == section ? .primary : .secondary
    }

    private var selectionFill: Color {
        isCinematic ? .white.opacity(0.17) : appTintColor.opacity(0.14)
    }

    private var selectionStroke: Color {
        isCinematic ? .white.opacity(0.22) : appTintColor.opacity(0.20)
    }
}

private struct HomeNavigationButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(AppMotion.feedback(reduceMotion: reduceMotion), value: configuration.isPressed)
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

private struct HomeAccountMessageButtonHost: View {
    let viewModel: AccountMessageCenterViewModel?
    let isCinematic: Bool
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if let viewModel {
            HomeAccountMessageButton(
                viewModel: viewModel,
                isCinematic: isCinematic,
                action: action
            )
        } else {
            HomeAccountMessageButtonContent(
                hasUnread: false,
                isCinematic: isCinematic,
                action: action
            )
        }
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
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .accessibilityLabel("账号消息")
        .accessibilityValue(hasUnread ? "有未读消息" : "全部已读")
    }
}
