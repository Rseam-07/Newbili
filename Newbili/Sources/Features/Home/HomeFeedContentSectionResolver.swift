import SwiftUI

struct HomeFeedContentSectionResolver: View {
    let metrics: HomeFeedLayoutMetrics
    let cells: [HomeVideoCellModel]
    let cellStartIndex: Int
    let lastSeenMarkerIndex: Int?
    let isLoadingMore: Bool
    let actions: HomeFeedContentActions

    var body: some View {
        Group {
            if cells.count <= cellStartIndex {
                HomeFeedSkeletonSection(metrics: metrics)
            } else if metrics.mode.isDoubleColumn {
                HomeFeedDoubleColumnContent(
                    metrics: metrics,
                    cells: cells,
                    cellStartIndex: cellStartIndex,
                    lastSeenMarkerIndex: lastSeenMarkerIndex,
                    isLoadingMore: isLoadingMore,
                    actions: actions
                )
            } else {
                HomeFeedSingleColumnContent(
                    metrics: metrics,
                    cells: cells,
                    cellStartIndex: cellStartIndex,
                    lastSeenMarkerIndex: lastSeenMarkerIndex,
                    isLoadingMore: isLoadingMore,
                    actions: actions
                )
            }
        }
    }
}
