import SwiftUI

struct DynamicFeedCard: View {
    let item: DynamicFeedItem
    let api: BiliAPIClient
    let likeController: DynamicLikeController
    let contentWidth: CGFloat?
    private let display: DynamicFeedCardDisplayModel
    @State private var commentsTarget: DynamicFeedItem?
    @State private var isTextExpanded = false

    init(
        item: DynamicFeedItem,
        api: BiliAPIClient,
        likeController: DynamicLikeController,
        contentWidth: CGFloat? = nil
    ) {
        self.item = item
        self.api = api
        self.likeController = likeController
        self.contentWidth = contentWidth
        let display = DynamicFeedCardDisplayModel(item: item)
        self.display = display
    }

    var body: some View {
        Group {
            if let video = display.video, display.usesHomeVideoCardStyle {
                DynamicHomeVideoFeedCard(
                    video: video,
                    display: display,
                    likeController: likeController,
                    onShowComments: showComments
                )
            } else if display.usesSeparatedDynamicLayout {
                DynamicSeparatedFeedCardContent(
                    item: item,
                    display: display,
                    contentWidth: contentWidth,
                    isTextExpanded: $isTextExpanded,
                    likeController: likeController,
                    onShowComments: showComments
                )
            } else {
                DynamicStandardFeedCardContent(
                    item: item,
                    display: display,
                    contentWidth: contentWidth,
                    isTextExpanded: $isTextExpanded,
                    likeController: likeController,
                    onShowComments: showComments
                )
            }
        }
        .sheet(item: $commentsTarget) { target in
            DynamicCommentsSheet(item: target, api: api)
        }
    }

    private func showComments() {
        commentsTarget = item
    }
}
