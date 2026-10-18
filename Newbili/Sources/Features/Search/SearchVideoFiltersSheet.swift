import SwiftUI

struct SearchVideoFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SearchViewModel
    @State private var draft: SearchVideoFilters

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.videoFilters)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("视频时长", selection: $draft.duration) {
                        ForEach(SearchVideoDuration.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("内容分区", selection: $draft.zone) {
                        ForEach(SearchVideoZone.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("发布时间", selection: $draft.published) {
                        ForEach(SearchVideoPublished.allCases) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text("筛选应用于综合和视频搜索中的视频结果。")
                }
                Section {
                    Button("重置筛选") { draft = SearchVideoFilters() }
                        .disabled(!draft.isActive)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppSurfaceColors.groupedPage)
            .navigationTitle("视频筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        let selected = draft
                        Task { await viewModel.selectVideoFilters(selected) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
