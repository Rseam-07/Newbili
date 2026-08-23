import SwiftUI

struct HomeFeedContentSection: View {
    let metrics: HomeFeedLayoutMetrics
    let cells: [HomeVideoCellModel]
    let cellStartIndex: Int
    let lastSeenMarkerIndex: Int?
    let isLoadingMore: Bool
    let actions: HomeFeedContentActions

    var body: some View {
        HomeFeedContentSectionResolver(
            metrics: metrics,
            cells: cells,
            cellStartIndex: cellStartIndex,
            lastSeenMarkerIndex: lastSeenMarkerIndex,
            isLoadingMore: isLoadingMore,
            actions: actions
        )
    }
}
