import SwiftUI

struct MineSearchSettingsSection: View {
    @ObservedObject var libraryStore: LibraryStore
    @State private var confirmsClearHistory = false

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { libraryStore.showsHotSearches },
                set: { libraryStore.setShowsHotSearches($0) }
            )) {
                Label("显示热门搜索", systemImage: "flame")
            }
            Toggle("显示搜索建议", systemImage: "magnifyingglass", isOn: Binding(
                get: { libraryStore.showsSearchSuggestions },
                set: { libraryStore.setShowsSearchSuggestions($0) }
            ))
            Toggle("记录搜索历史", systemImage: "clock.arrow.circlepath", isOn: Binding(
                get: { libraryStore.recordsSearchHistory },
                set: { libraryStore.setRecordsSearchHistory($0) }
            ))
            Button("清空搜索历史", systemImage: "trash", role: .destructive) {
                confirmsClearHistory = true
            }
            .disabled(libraryStore.searchHistory.isEmpty)
        } header: {
            Text("搜索")
        } footer: {
            Text("搜索历史保存在此设备，最多 30 条。无痕模式不记录、不显示历史。关闭搜索建议会停止联想请求。")
        }
        .confirmationDialog("清空搜索历史？", isPresented: $confirmsClearHistory, titleVisibility: .visible) {
            Button("清空历史", role: .destructive) { libraryStore.clearSearchHistory() }
            Button("取消", role: .cancel) {}
        }
    }
}
