import SwiftUI

struct SearchLoadingList: View {
    @State private var statusBarHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    SearchLoadingContent(scope: .comprehensive)
                }
                .padding(.horizontal, 16)
                .padding(.top, SearchTopBarLayout.contentTopInset(for: statusBarHeight) + 20)
                .padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollBounceBehavior(.always, axes: .vertical)
            .background(Color(.systemBackground))
            .ignoresSafeArea(.container, edges: .top)
            .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)

            SkeletonBlock(height: SearchTopBarLayout.height, shape: .rounded(22))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, SearchTopBarLayout.topInset(for: statusBarHeight))
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowStatusBarHeightReader(height: $statusBarHeight))
        .background(Color(.systemBackground))
    }
}
