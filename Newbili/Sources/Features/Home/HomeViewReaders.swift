import SwiftUI

struct HomePullRefreshOffsetReader: View {
    var coordinateSpaceName = HomePullRefreshCoordinateSpace.name

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: HomePullRefreshDistancePreferenceKey.self,
                value: HomePullRefreshCoordinateSpace.quantizedPullDistance(
                    proxy.frame(in: .named(coordinateSpaceName)).minY
                )
            )
        }
        .frame(height: 0)
    }
}
