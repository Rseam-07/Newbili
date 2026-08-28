import SwiftUI

struct DynamicHomeVideoFeedCard: View {
    let video: VideoItem
    let display: DynamicFeedCardDisplayModel
    let likeController: DynamicLikeController
    let onShowComments: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            authorHeader
                .padding(.horizontal, 12)

            VideoRouteLink(video) {
                VStack(alignment: .leading, spacing: 9) {
                    VStack(alignment: .leading, spacing: 0) {
                        DynamicVideoTitleText(
                            video.title,
                            style: .feed,
                            lineLimit: 1
                        )
                    }
                    .padding(.horizontal, 12)

                    if let videoDisplay = display.videoDisplay {
                        DynamicFeedVideoCover(video: video, display: videoDisplay)
                    }
                }
                .contentShape(Rectangle())
            }

            DynamicFeedActionBar(
                display: display,
                likeController: likeController,
                onShowComments: onShowComments
            )
        }
        .padding(.top, 5)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("鐟欏棝顣?\(video.title)")
    }

    private var authorHeader: some View {
        DynamicFeedAuthorHeader(display: display)
    }
}
