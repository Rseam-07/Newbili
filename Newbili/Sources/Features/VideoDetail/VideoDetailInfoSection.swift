import SwiftUI

struct VideoDetailInfoBlock: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @ObservedObject var store: VideoDetailDescriptionRenderStore
    @State private var expansionOverride: Bool?

    private var isExpanded: Bool {
        expansionOverride ?? libraryStore.expandsVideoDescriptionByDefault
    }

    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { isExpanded },
            set: { expansionOverride = $0 }
        )
    }

    var body: some View {
        Group {
            if store.hasResolvedDetailMetadata {
                VStack(alignment: .leading, spacing: 8) {
                    VideoDetailResolvedInfoContent(
                        store: store,
                        isExpanded: isExpandedBinding
                    )

                    if libraryStore.videoIntelligenceSummaryEnabled {
                        VideoDescriptionIntelligenceView(
                            bvid: store.bvid,
                            cid: store.cid,
                            title: store.titleText,
                            description: store.descriptionText,
                            isPresented: isExpanded
                        )
                    }
                }
            } else {
                VideoDetailInfoLoadingPlaceholder(titleText: store.titleText)
            }
        }
    }
}
