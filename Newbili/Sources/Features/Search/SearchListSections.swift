import SwiftUI

struct SearchSortHeaderButton: View {
    @ObservedObject var viewModel: SearchViewModel
    var showsContainer = true
    @State private var showsVideoFilters = false

    var body: some View {
        Menu {
            ForEach(SearchSortOrder.allCases) { order in
                Button {
                    Task { await viewModel.selectOrder(order) }
                } label: {
                    Label(order.title, systemImage: order == viewModel.selectedOrder ? "checkmark" : "arrow.up.arrow.down")
                }
            }
            Divider()
            Button {
                showsVideoFilters = true
            } label: {
                Label("视频筛选", systemImage: viewModel.videoFilters.isActive
                      ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            if viewModel.videoFilters.isActive {
                Text(viewModel.videoFilters.summary)
            }
        } label: {
            sortLabel
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.selectedScope.supportsOrder)
        .opacity(viewModel.selectedScope.supportsOrder ? 1 : 0.42)
        .animation(.smooth(duration: 0.22), value: viewModel.selectedScope.supportsOrder)
        .accessibilityLabel("搜索排序和筛选")
        .accessibilityValue([viewModel.selectedOrder.title, viewModel.videoFilters.summary].filter { !$0.isEmpty }.joined(separator: "，"))
        .sheet(isPresented: $showsVideoFilters) { SearchVideoFiltersSheet(viewModel: viewModel) }
    }

    @ViewBuilder
    private var sortLabel: some View {
        let label = Label(sortTitle, systemImage: viewModel.videoFilters.isActive
                          ? "line.3.horizontal.decrease.circle.fill" : "arrow.up.arrow.down")
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .foregroundStyle(viewModel.selectedScope.supportsOrder ? Color.primary : Color.secondary)
            .frame(minWidth: 58)
            .frame(height: 36)
            .padding(.horizontal, 10)

        if showsContainer {
            label
                .biliBottomTabGlassEffect(interactive: false, in: Capsule())
        } else {
            label
        }
    }

    private var sortTitle: String {
        viewModel.selectedScope.supportsOrder ? viewModel.selectedOrder.shortTitle : "排序"
    }
}
