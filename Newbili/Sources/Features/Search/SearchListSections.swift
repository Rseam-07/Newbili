import SwiftUI

struct SearchSortHeaderButton: View {
    @ObservedObject var viewModel: SearchViewModel
    var showsContainer = true

    var body: some View {
        Menu {
            ForEach(SearchSortOrder.allCases) { order in
                Button {
                    Task { await viewModel.selectOrder(order) }
                } label: {
                    Label(order.title, systemImage: order == viewModel.selectedOrder ? "checkmark" : "arrow.up.arrow.down")
                }
            }
        } label: {
            sortLabel
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.selectedScope.supportsOrder)
        .opacity(viewModel.selectedScope.supportsOrder ? 1 : 0.42)
        .animation(.smooth(duration: 0.22), value: viewModel.selectedScope.supportsOrder)
        .accessibilityLabel("搜索结果排序")
        .accessibilityValue(viewModel.selectedOrder.title)
    }

    @ViewBuilder
    private var sortLabel: some View {
        let label = Label(sortTitle, systemImage: "arrow.up.arrow.down")
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
