import SwiftUI

struct WatchLaterListPage: View {
    @ObservedObject var viewModel: MineViewModel
    @EnvironmentObject private var sessionStore: SessionStore

    @State private var filter: WatchLaterFilter = .all
    @State private var sortOrder: WatchLaterSortOrder = .newest
    @State private var searchText = ""
    @State private var appliedSearchText = ""
    @State private var isSelecting = false
    @State private var selectedAIDs = Set<Int>()
    @State private var pendingRemovalAIDs = Set<Int>()
    @State private var showsRemovalConfirmation = false
    @State private var pendingClearScope: WatchLaterClearScope?
    @State private var showsClearConfirmation = false
    @State private var showsAddPrompt = false
    @State private var addIdentifier = ""
    @State private var notice: WatchLaterNotice?

    var body: some View {
        List {
            if sessionStore.isLoggedIn {
                filterSection
            }

            Section {
                content
            } header: {
                if sessionStore.isLoggedIn, viewModel.watchLaterState == .loaded {
                    Text(resultSummary)
                }
            }

            if let notice {
                Section {
                    Label(notice.message, systemImage: notice.isError ? "exclamationmark.circle" : "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(notice.isError ? .orange : .secondary)
                }
            }
        }
        .nativeTopScrollEdgeEffect()
        .navigationTitle("稍后再看")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索稍后再看")
        .onSubmit(of: .search, applySearch)
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty, !appliedSearchText.isEmpty {
                appliedSearchText = ""
                Task { await reload() }
            }
        }
        .onChange(of: filter) { _, _ in
            selectedAIDs.removeAll()
            Task { await reload() }
        }
        .toolbar { toolbarContent }
        .task { await loadIfNeeded() }
        .refreshable { await reload() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting {
                selectionBar
            }
        }
        .confirmationDialog(
            "确认移除",
            isPresented: $showsRemovalConfirmation,
            titleVisibility: .visible
        ) {
            Button("移除 \(pendingRemovalAIDs.count) 个视频", role: .destructive) {
                Task { await removePendingVideos() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所选视频将从稍后再看列表移除。")
        }
        .confirmationDialog(
            pendingClearScope?.title ?? "清理稍后再看",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            if let scope = pendingClearScope {
                Button(scope.title, role: .destructive) {
                    Task { await clear(scope) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(pendingClearScope?.confirmationMessage ?? "")
        }
        .alert("加入稍后再看", isPresented: $showsAddPrompt) {
            TextField("AV 号或 BV 号", text: $addIdentifier)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("加入") {
                let identifier = addIdentifier
                addIdentifier = ""
                Task { await add(identifier) }
            }
            Button("取消", role: .cancel) {
                addIdentifier = ""
            }
        } message: {
            Text("可输入 av170001、170001 或完整 BV 号。")
        }
    }

    private var filterSection: some View {
        Section {
            Picker("筛选", selection: $filter) {
                ForEach(WatchLaterFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.watchLaterState.isLoading)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !sessionStore.isLoggedIn {
            LibraryEmptyRow(title: "登录后同步稍后再看", systemImage: "bookmark")
        } else if viewModel.watchLaterEntries.isEmpty && viewModel.watchLaterState.isLoading {
            LibraryLoadingRow(title: "正在同步稍后再看")
        } else if viewModel.watchLaterEntries.isEmpty, case .failed(let message) = viewModel.watchLaterState {
            LibraryErrorRow(title: "稍后再看同步失败", message: message) {
                Task { await reload() }
            }
        } else if viewModel.watchLaterEntries.isEmpty {
            LibraryEmptyRow(
                title: appliedSearchText.isEmpty ? "稍后再看列表为空" : "没有找到相关视频",
                systemImage: appliedSearchText.isEmpty ? "bookmark" : "magnifyingglass"
            )
        } else {
            ForEach(viewModel.watchLaterEntries) { item in
                watchLaterRow(item)
                    .task { await viewModel.loadMoreWatchLaterIfNeeded(current: item) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if let aid = item.aid, aid > 0 {
                            Button(role: .destructive) {
                                requestRemoval([aid])
                            } label: {
                                Label("移除", systemImage: "trash")
                            }
                        }
                    }
            }

            if viewModel.watchLaterState.isLoading {
                LibraryLoadingRow(title: "正在刷新稍后再看")
            } else if case .failed(let message) = viewModel.watchLaterState {
                LibraryErrorRow(title: "稍后再看刷新失败", message: message) {
                    Task { await reload() }
                }
            } else if viewModel.watchLaterLoadMoreState.isLoading {
                LibraryLoadingRow(title: "正在加载更多稍后再看")
            } else if case .failed(let message) = viewModel.watchLaterLoadMoreState {
                LibraryErrorRow(title: "更多内容加载失败", message: message) {
                    Task { await viewModel.loadMoreWatchLater() }
                }
            } else if viewModel.watchLaterHasMore {
                LibraryLoadMoreTriggerRow(title: "正在加载更多稍后再看") {
                    Task { await viewModel.loadMoreWatchLater() }
                }
            }
        }
    }

    @ViewBuilder
    private func watchLaterRow(_ item: AccountVideoEntry) -> some View {
        if isSelecting {
            Button {
                toggleSelection(item.aid)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isSelected(item.aid) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected(item.aid) ? Color.accentColor : .secondary)
                        .font(.title3)
                    LibraryVideoRow(item: item, timestampTitle: "发布于")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled((item.aid ?? 0) <= 0)
        } else {
            VideoRouteLink(item.videoItem) {
                LibraryVideoRow(item: item, timestampTitle: "发布于")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { finishSelecting() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(selectionActionTitle) { toggleSelectAll() }
                    .disabled(selectableAIDs.isEmpty)
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showsAddPrompt = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!sessionStore.isLoggedIn || mutationInProgress)
                .accessibilityLabel("加入稍后再看")

                Menu {
                    Button {
                        isSelecting = true
                        selectedAIDs.removeAll()
                    } label: {
                        Label("选择视频", systemImage: "checkmark.circle")
                    }
                    .disabled(viewModel.watchLaterEntries.isEmpty)

                    Picker("排序", selection: $sortOrder) {
                        ForEach(WatchLaterSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .onChange(of: sortOrder) { _, _ in
                        Task { await reload() }
                    }

                    Divider()

                    Button {
                        Task { await reload() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }

                    Menu("清理列表", systemImage: "trash") {
                        ForEach(WatchLaterClearScope.allCases) { scope in
                            Button(scope.title, role: scope == .all ? .destructive : nil) {
                                pendingClearScope = scope
                                showsClearConfirmation = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(!sessionStore.isLoggedIn || mutationInProgress)
                .accessibilityLabel("更多稍后再看操作")
            }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text(selectedAIDs.isEmpty ? "请选择视频" : "已选择 \(selectedAIDs.count) 个")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button(role: .destructive) {
                requestRemoval(selectedAIDs)
            } label: {
                Label("移除", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedAIDs.isEmpty || mutationInProgress)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var resultSummary: String {
        let count = viewModel.watchLaterTotalCount
        if appliedSearchText.isEmpty {
            return "\(filter.title) · \(count) 个视频 · \(sortOrder.title)"
        }
        return "“\(appliedSearchText)” · \(count) 个结果"
    }

    private var mutationInProgress: Bool {
        viewModel.watchLaterMutationState.isLoading
    }

    private var selectableAIDs: Set<Int> {
        Set(viewModel.watchLaterEntries.compactMap { entry in
            guard let aid = entry.aid, aid > 0 else { return nil }
            return aid
        })
    }

    private var selectionActionTitle: String {
        !selectableAIDs.isEmpty && selectedAIDs == selectableAIDs ? "取消全选" : "全选"
    }

    private func loadIfNeeded() async {
        await viewModel.loadAccountLibrary(loadRequest)
    }

    private func reload() async {
        await viewModel.loadAccountLibrary(loadRequest, policy: .reload)
    }

    private var loadRequest: AccountLibraryLoadRequest {
        .watchLater(
            filter: filter,
            keyword: appliedSearchText,
            sortOrder: sortOrder
        )
    }

    private func applySearch() {
        appliedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedAIDs.removeAll()
        Task { await reload() }
    }

    private func isSelected(_ aid: Int?) -> Bool {
        aid.map(selectedAIDs.contains) == true
    }

    private func toggleSelection(_ aid: Int?) {
        guard let aid, aid > 0 else { return }
        if !selectedAIDs.insert(aid).inserted {
            selectedAIDs.remove(aid)
        }
    }

    private func toggleSelectAll() {
        selectedAIDs = selectedAIDs == selectableAIDs ? [] : selectableAIDs
    }

    private func finishSelecting() {
        isSelecting = false
        selectedAIDs.removeAll()
    }

    private func requestRemoval(_ aids: Set<Int>) {
        guard !aids.isEmpty else { return }
        pendingRemovalAIDs = aids
        showsRemovalConfirmation = true
    }

    private func removePendingVideos() async {
        let aids = pendingRemovalAIDs
        pendingRemovalAIDs.removeAll()
        do {
            try await viewModel.removeFromWatchLater(aids: aids)
            selectedAIDs.subtract(aids)
            if selectedAIDs.isEmpty {
                isSelecting = false
            }
            notice = WatchLaterNotice(message: "已移除 \(aids.count) 个视频", isError: false)
        } catch {
            notice = WatchLaterNotice(message: error.localizedDescription, isError: true)
        }
    }

    private func clear(_ scope: WatchLaterClearScope) async {
        do {
            try await viewModel.clearWatchLater(scope: scope)
            finishSelecting()
            notice = WatchLaterNotice(message: "\(scope.title)完成", isError: false)
        } catch {
            notice = WatchLaterNotice(message: error.localizedDescription, isError: true)
        }
        pendingClearScope = nil
    }

    private func add(_ identifier: String) async {
        do {
            try await viewModel.addToWatchLater(identifier: identifier)
            notice = WatchLaterNotice(message: "已加入稍后再看", isError: false)
        } catch {
            notice = WatchLaterNotice(message: error.localizedDescription, isError: true)
        }
    }
}

private struct WatchLaterNotice: Equatable {
    let message: String
    let isError: Bool
}
