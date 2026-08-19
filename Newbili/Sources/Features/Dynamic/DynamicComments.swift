import SwiftUI

struct DynamicCommentsSheet: View {
    let item: DynamicFeedItem
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: DynamicCommentsViewModel
    @StateObject private var runtimeSettings = DynamicCommentsRuntimeSettingsStore()
    @State private var replySheetComment: Comment?

    init(item: DynamicFeedItem, api: BiliAPIClient) {
        self.item = item
        _viewModel = StateObject(wrappedValue: DynamicCommentsViewModel(item: item, api: api))
    }

    private var commentContentOwnerMID: Int? {
        guard let mid = item.author?.mid, mid > 0 else { return nil }
        return mid
    }

    var body: some View {
        CommentOwnerProfileNavigationContainer {
            ScrollView {
                DynamicCommentsSheetContent(item: item, viewModel: viewModel) { comment in
                    replySheetComment = comment
                }
            }
            .defersRemoteImageLoadsDuringFastScroll()
            .hiddenInlineNavigationTitle()
            .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)
            .task {
                runtimeSettings.bind(dependencies.libraryStore)
                viewModel.setBlocksGoodsComments(runtimeSettings.blocksGoodsComments)
                await viewModel.loadInitial()
            }
        }
        .environment(\.commentContentOwnerMID, commentContentOwnerMID)
        .onChange(of: runtimeSettings.blocksGoodsComments) { _, isEnabled in
            viewModel.setBlocksGoodsComments(isEnabled)
        }
        .presentationDetents([.fraction(0.7)])
        .presentationDragIndicator(.visible)
        .sheet(item: $replySheetComment) { comment in
            DynamicCommentRepliesSheet(rootComment: comment, replyStore: viewModel.replyStore)
                .environment(\.commentContentOwnerMID, commentContentOwnerMID)
        }
    }
}
