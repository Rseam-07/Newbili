import Combine
import SwiftUI
import UIKit

struct SearchContentView: View {
    @Environment(\.scrollEdgeEffectPreference) private var scrollEdgeEffectPreference
    @ObservedObject var viewModel: SearchViewModel
    let showsHotSearches: Bool
    @ObservedObject var accessoryStore: SearchBottomAccessoryStore
    @State private var isSearchFocused = false
    @State private var statusBarHeight: CGFloat = 0
    @StateObject private var scrollEdgeStore = SearchScrollEdgeStore()

    var body: some View {
        ZStack(alignment: .top) {
            SearchListView(
                viewModel: viewModel,
                showsHotSearches: showsHotSearches,
                topContentInset: SearchTopBarLayout.contentTopInset(for: statusBarHeight),
                scrollEdgeStore: scrollEdgeStore
            )

            NativeSearchBar(
                text: queryBinding,
                isFocused: Binding(
                    get: { isSearchFocused },
                    set: { isSearchFocused = $0 }
                ),
                prompt: viewModel.searchPrompt,
                edgeEffectPreference: scrollEdgeEffectPreference,
                targetScrollView: targetScrollView,
                onSubmit: {
                    Task { await viewModel.search() }
                }
            )
            .frame(maxWidth: .infinity)
            .frame(height: SearchTopBarLayout.height)
            .padding(.horizontal, 16)
            .padding(.top, SearchTopBarLayout.topInset(for: statusBarHeight))
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowStatusBarHeightReader(height: $statusBarHeight))
        .overlay {
            if case .failed(let message) = viewModel.state, viewModel.results.isEmpty {
                ErrorStateView(title: "搜索失败", message: message) {
                    Task { await viewModel.search() }
                }
            }
        }
        .task {
            accessoryStore.attach(viewModel)
            await loadHotSearchIfNeeded()
        }
        .onChange(of: isSearchFocused) { _, isFocused in
            accessoryStore.isSearchFocused = isFocused
        }
        .onDisappear {
            accessoryStore.isSearchFocused = false
        }
        .toolbar {
            if isSearchFocused {
                ToolbarItem(placement: .keyboard) {
                    SearchBottomControls(viewModel: viewModel)
                }
            }
        }
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { viewModel.query },
            set: { query in
                viewModel.query = query
                viewModel.queryChanged()
            }
        )
    }

    private var targetScrollView: UIScrollView? {
        _ = scrollEdgeStore.revision
        return scrollEdgeStore.scrollView
    }

    private func loadHotSearchIfNeeded() async {
        guard showsHotSearches else { return }
        await viewModel.loadHotSearch()
    }
}

enum SearchTopBarLayout {
    static let height: CGFloat = 44
    static let verticalPadding: CGFloat = 6

    static func topInset(for safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + verticalPadding
    }

    static func contentTopInset(for safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + height + verticalPadding * 2
    }
}

@MainActor
final class SearchScrollEdgeStore: ObservableObject {
    @Published private(set) var revision = 0
    weak var scrollView: UIScrollView?

    func attach(_ scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }
        self.scrollView = scrollView
        revision &+= 1
    }
}

struct SearchScrollViewProbe: UIViewRepresentable {
    let store: SearchScrollEdgeStore

    func makeUIView(context _: Context) -> ProbeView {
        ProbeView(store: store)
    }

    func updateUIView(_ uiView: ProbeView, context _: Context) {
        uiView.store = store
        uiView.reportScrollView()
    }

    final class ProbeView: UIView {
        weak var store: SearchScrollEdgeStore?

        init(store: SearchScrollEdgeStore) {
            self.store = store
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            reportScrollView()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportScrollView()
        }

        func reportScrollView() {
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    store?.attach(scrollView)
                    return
                }
                ancestor = view.superview
            }
        }
    }
}

struct WindowStatusBarHeightReader: UIViewRepresentable {
    @Binding var height: CGFloat

    func makeUIView(context _: Context) -> ReaderView {
        let binding = $height
        return ReaderView { value in
            guard abs(binding.wrappedValue - value) > 0.5 else { return }
            DispatchQueue.main.async {
                guard abs(binding.wrappedValue - value) > 0.5 else { return }
                binding.wrappedValue = value
            }
        }
    }

    func updateUIView(_ uiView: ReaderView, context _: Context) {
        uiView.reportStatusBarHeight()
    }

    final class ReaderView: UIView {
        private let onChange: (CGFloat) -> Void

        init(onChange: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportStatusBarHeight()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            reportStatusBarHeight()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            reportStatusBarHeight()
        }

        func reportStatusBarHeight() {
            onChange(window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0)
        }
    }
}

private struct NativeSearchBar: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let prompt: String
    let edgeEffectPreference: AppScrollEdgeEffectPreference
    let targetScrollView: UIScrollView?
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> SearchBarContainerView {
        let container = SearchBarContainerView()
        let searchBar = container.searchBar
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = prompt
        searchBar.autocapitalizationType = .none
        searchBar.returnKeyType = .search
        searchBar.delegate = context.coordinator
        searchBar.searchTextField.clearButtonMode = .whileEditing
        return container
    }

    func updateUIView(_ container: SearchBarContainerView, context: Context) {
        context.coordinator.parent = self
        let searchBar = container.searchBar
        let searchField = searchBar.searchTextField
        if searchBar.text != text, searchField.markedTextRange == nil {
            searchBar.text = text
        }

        container.edgeEffectPreference = edgeEffectPreference
        container.targetScrollView = targetScrollView
        container.refreshScrollEdgeBinding()

        if isFocused, !searchField.isFirstResponder {
            DispatchQueue.main.async {
                searchField.becomeFirstResponder()
            }
        } else if !isFocused, searchField.isFirstResponder {
            searchBar.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: NativeSearchBar

        init(parent: NativeSearchBar) {
            self.parent = parent
        }

        func searchBarTextDidBeginEditing(_: UISearchBar) {
            parent.isFocused = true
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            parent.isFocused = false
            syncCommittedText(from: searchBar)
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange _: String) {
            syncCommittedText(from: searchBar)
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            syncCommittedText(from: searchBar)
            parent.isFocused = false
            searchBar.resignFirstResponder()
            parent.onSubmit()
        }

        private func syncCommittedText(from searchBar: UISearchBar) {
            guard searchBar.searchTextField.markedTextRange == nil else { return }
            let searchText = searchBar.text ?? ""
            guard parent.text != searchText else { return }
            parent.text = searchText
        }
    }

    final class SearchBarContainerView: UIView {
        let searchBar = UISearchBar()
        var edgeEffectPreference: AppScrollEdgeEffectPreference = .soft
        weak var targetScrollView: UIScrollView?
        private var scrollEdgeInteraction: UIScrollEdgeElementContainerInteraction?

        override init(frame: CGRect) {
            super.init(frame: frame)
            searchBar.translatesAutoresizingMaskIntoConstraints = false
            addSubview(searchBar)
            NSLayoutConstraint.activate([
                searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
                searchBar.trailingAnchor.constraint(equalTo: trailingAnchor),
                searchBar.topAnchor.constraint(equalTo: topAnchor),
                searchBar.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

            if #available(iOS 26.0, *) {
                let interaction = UIScrollEdgeElementContainerInteraction()
                interaction.edge = .top
                addInteraction(interaction)
                scrollEdgeInteraction = interaction
            }
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            refreshScrollEdgeBinding()
        }

        func refreshScrollEdgeBinding() {
            guard let targetScrollView else { return }
            scrollEdgeInteraction?.scrollView = targetScrollView
            applyEdgeEffectStyle(to: targetScrollView)
        }

        private func applyEdgeEffectStyle(to scrollView: UIScrollView) {
            guard #available(iOS 26.0, *) else { return }
            switch edgeEffectPreference {
            case .soft:
                scrollView.topEdgeEffect.style = .soft
            case .hard:
                scrollView.topEdgeEffect.style = .hard
            case .automatic:
                scrollView.topEdgeEffect.style = .automatic
            }
        }

    }
}

struct SearchBottomControls: View {
    @ObservedObject var viewModel: SearchViewModel
    var showsContainer = true

    @ViewBuilder
    var body: some View {
        if showsContainer {
            controlContent
                .biliBottomTabGlassEffect(interactive: false, in: Capsule())
        } else {
            controlContent
        }
    }

    private var controlContent: some View {
        HStack(spacing: 0) {
            BiliGlassSegmentedControl(
                options: Array(SearchScope.allCases),
                selected: viewModel.selectedScope,
                title: { $0.title },
                select: { scope in
                    Task {
                        await viewModel.selectScope(scope, animation: .smooth(duration: 0.28))
                    }
                },
                showsContainer: false
            )
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 20)

            SearchSortHeaderButton(viewModel: viewModel, showsContainer: false)
                .frame(minWidth: 86)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityLabel("搜索类型和排序")
    }
}

struct SearchTabBottomAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @ObservedObject var store: SearchBottomAccessoryStore

    @ViewBuilder
    var body: some View {
        if let viewModel = store.viewModel {
            if usesInlineLayout {
                SearchInlineBottomControls(viewModel: viewModel)
            } else {
                SearchBottomControls(viewModel: viewModel, showsContainer: false)
            }
        }
    }

    private var usesInlineLayout: Bool {
        placement == .inline
    }
}

private struct SearchInlineBottomControls: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(SearchScope.allCases) { scope in
                    Button {
                        Task {
                            await viewModel.selectScope(scope, animation: .smooth(duration: 0.28))
                        }
                    } label: {
                        Label(
                            scope.title,
                            systemImage: scope == viewModel.selectedScope
                                ? "checkmark"
                                : scope.systemImage
                        )
                    }
                }
            } label: {
                ZStack {
                    Color.clear

                    HStack(spacing: 6) {
                        ViewThatFits(in: .horizontal) {
                            Label(viewModel.selectedScope.title, systemImage: viewModel.selectedScope.systemImage)
                            Image(systemName: viewModel.selectedScope.systemImage)
                        }
                    }
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())

            if viewModel.selectedScope.supportsOrder {
                Divider()
                    .frame(height: 20)

                Menu {
                    ForEach(SearchSortOrder.allCases) { order in
                        Button {
                            Task { await viewModel.selectOrder(order) }
                        } label: {
                            Label(
                                order.title,
                                systemImage: order == viewModel.selectedOrder
                                    ? "checkmark"
                                    : "arrow.up.arrow.down"
                            )
                        }
                    }
                } label: {
                    ZStack {
                        Color.clear

                        Label(viewModel.selectedOrder.shortTitle, systemImage: "arrow.up.arrow.down")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .accessibilityLabel("搜索结果排序")
                .accessibilityValue(viewModel.selectedOrder.title)
            }
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .contain)
    }
}
