import SwiftUI

struct HomeFeedNavigationChrome: ViewModifier {
    @ObservedObject var viewModel: HomeViewModel
    let modeActions: HomeFeedModeActions
    let accountMessageViewModel: AccountMessageCenterViewModel?
    let isModeSwitcherExperimentEnabled: Bool
    let onOpenAccountMessages: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isModeSwitcherExperimentEnabled {
            content
                .rootNavigationTitle(
                    "首页",
                    accessoryUsesFullWidth: true
                ) {
                    GlassEffectContainer(spacing: 8) {
                        ZStack {
                            HomeNavigationModeControl(
                                viewModel: viewModel,
                                onSelectMode: switchMode
                            )
                            .frame(width: 112)

                            accountMessageButton
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                .nativeTopNavigationChrome()
        } else {
            content
                .rootNavigationTitle("首页") {
                    HomeFeedModeMenu(currentMode: viewModel.mode, onSelectMode: switchMode)
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

    private func switchMode(_ mode: HomeFeedMode) {
        modeActions.switchMode(mode, viewModel: viewModel)
    }
}

extension View {
    func homeFeedNavigationChrome(
        viewModel: HomeViewModel,
        modeActions: HomeFeedModeActions,
        accountMessageViewModel: AccountMessageCenterViewModel?,
        isModeSwitcherExperimentEnabled: Bool,
        onOpenAccountMessages: @escaping () -> Void
    ) -> some View {
        modifier(
            HomeFeedNavigationChrome(
                viewModel: viewModel,
                modeActions: modeActions,
                accountMessageViewModel: accountMessageViewModel,
                isModeSwitcherExperimentEnabled: isModeSwitcherExperimentEnabled,
                onOpenAccountMessages: onOpenAccountMessages
            )
        )
    }
}

private enum HomeNavigationModeOption: String, CaseIterable, Identifiable, Hashable {
    case recommend
    case popular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommend:
            return "推荐"
        case .popular:
            return "热门"
        }
    }
}

private struct HomeNavigationModeControl: View {
    @ObservedObject var viewModel: HomeViewModel
    let onSelectMode: (HomeFeedMode) -> Void
    @State private var selectedOption: HomeNavigationModeOption

    init(
        viewModel: HomeViewModel,
        onSelectMode: @escaping (HomeFeedMode) -> Void
    ) {
        self.viewModel = viewModel
        self.onSelectMode = onSelectMode
        _selectedOption = State(initialValue: Self.option(for: viewModel.mode))
    }

    var body: some View {
        Picker(
            "首页模式",
            selection: Binding(
                get: { selectedOption },
                set: select
            )
        ) {
            ForEach(HomeNavigationModeOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .labelsHidden()
        .accessibilityLabel("首页模式")
        .onAppear {
            selectedOption = Self.option(for: viewModel.mode)
        }
        .onChange(of: viewModel.mode) { _, mode in
            selectedOption = Self.option(for: mode)
        }
    }

    private func select(_ option: HomeNavigationModeOption) {
        switch option {
        case .recommend:
            selectedOption = option
            onSelectMode(.recommend)
        case .popular:
            selectedOption = option
            onSelectMode(.popular)
        }
    }

    private static func option(for mode: HomeFeedMode) -> HomeNavigationModeOption {
        switch mode {
        case .recommend:
            return .recommend
        case .popular:
            return .popular
        }
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
