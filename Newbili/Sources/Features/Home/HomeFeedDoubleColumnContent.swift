import SwiftUI

struct HomeFeedDoubleColumnContent: View {
    let metrics: HomeFeedLayoutMetrics
    let cells: [HomeVideoCellModel]
    let cellStartIndex: Int
    let lastSeenMarkerIndex: Int?
    let isLoadingMore: Bool
    let actions: HomeFeedContentActions

    private var loadMoreTriggerCellID: String? {
        cells.last?.id
    }

    private var visibleCells: ArraySlice<HomeVideoCellModel> {
        cells.dropFirst(cellStartIndex)
    }

    private var visibleLastSeenMarkerIndex: Int? {
        guard let lastSeenMarkerIndex,
              lastSeenMarkerIndex > 0,
              lastSeenMarkerIndex < visibleCells.count
        else { return nil }
        return lastSeenMarkerIndex
    }

    var body: some View {
        LazyVGrid(columns: metrics.feedColumns, spacing: metrics.feedSpacing) {
            ForEach(visibleCells) { cell in
                if visibleLastSeenMarkerIndex == cell.index {
                    HomeFeedLastSeenMarkerCard(
                        metrics: metrics,
                        action: actions.onRefreshFromLastSeenMarker
                    )
                }

                HomeFeedDoubleColumnCard(
                    metrics: metrics,
                    cell: cell,
                    loadMoreTriggerCellID: loadMoreTriggerCellID,
                    actions: actions
                )
            }

            if isLoadingMore {
                HomeFeedDoubleColumnLoadingMorePlaceholder(columnCount: metrics.feedColumns.count)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.feedHorizontalPadding)
    }
}
