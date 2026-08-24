import SwiftUI

struct VideoDetailUserAnimeSection<ActionContent: View>: View {
    let detail: VideoItem
    @ObservedObject var pageStore: VideoDetailPageSelectorRenderStore
    let selectPage: (VideoPage) -> Void
    @ViewBuilder let actionContent: () -> ActionContent

    @State private var isEpisodeSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VideoDetailUserAnimeInfoBlock(detail: detail)

            actionContent()

            if !pageStore.pages.isEmpty {
                VideoDetailUserAnimeEpisodeRail(
                    pages: pageStore.pages,
                    selectedCID: pageStore.selectedCID,
                    selectPage: selectPage,
                    showAll: { isEpisodeSheetPresented = true }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isEpisodeSheetPresented) {
            VideoDetailUserAnimeEpisodeSheet(
                pages: pageStore.pages,
                selectedCID: pageStore.selectedCID,
                selectPage: selectPage
            )
        }
    }
}

private struct VideoDetailUserAnimeInfoBlock: View {
    let detail: VideoItem
    @State private var isDescriptionExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                poster

                VStack(alignment: .leading, spacing: 8) {
                    Label("用户标记番剧", systemImage: "sparkles.tv")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.78), in: Capsule())

                    Text(detail.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)

                    Text(episodeSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let ownerName {
                        Label(ownerName, systemImage: "person.crop.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        Label(BiliFormatters.compactCount(detail.stat?.view), systemImage: "play.fill")
                        Label(BiliFormatters.compactCount(detail.stat?.reply), systemImage: "bubble.left.fill")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let descriptionText {
                VStack(alignment: .leading, spacing: 6) {
                    Text(descriptionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(isDescriptionExpanded ? nil : 3)
                        .textSelection(.enabled)

                    if needsDescriptionExpansion {
                        Button(isDescriptionExpanded ? "收起简介" : "展开简介") {
                            withAnimation(.snappy(duration: 0.22)) {
                                isDescriptionExpanded.toggle()
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(alignment: .center) {
            backgroundArtwork
        }
        .background(Color(.systemBackground).opacity(0.58))
        .biliRegularGlassEffect(interactive: false, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .contain)
    }

    private var poster: some View {
        CachedRemoteImage(
            url: artworkURL,
            targetPixelSize: 420,
            animatesAppearance: true
        ) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            BiliMediaPlaceholder(style: .video, iconSize: 24)
        }
        .frame(width: 94, height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.22), radius: 9, x: 0, y: 5)
    }

    private var backgroundArtwork: some View {
        CachedRemoteImage(
            url: artworkURL,
            targetPixelSize: 720,
            animatesAppearance: false
        ) { image in
            image
                .resizable()
                .scaledToFill()
                .blur(radius: 26)
                .scaleEffect(1.18)
                .opacity(0.22)
        } placeholder: {
            Color.clear
        }
        .overlay {
            LinearGradient(
                colors: [Color.clear, Color(.systemBackground).opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .allowsHitTesting(false)
    }

    private var artworkURL: URL? {
        guard let picture = detail.pic?.normalizedBiliURL(), !picture.isEmpty else { return nil }
        return URL(string: picture.biliCoverThumbnailURL(width: 720, height: 960))
    }

    private var episodeSummary: String {
        let count = max(detail.pages?.count ?? 0, 1)
        return "全 \(count) 集 · UGC 番剧模式"
    }

    private var ownerName: String? {
        let name = detail.owner?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    private var descriptionText: String? {
        let text = detail.desc?.removingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private var needsDescriptionExpansion: Bool {
        guard let descriptionText else { return false }
        return descriptionText.count > 88 || descriptionText.contains("\n")
    }
}

private struct VideoDetailUserAnimeEpisodeRail: View {
    let pages: [VideoPage]
    let selectedCID: Int?
    let selectPage: (VideoPage) -> Void
    let showAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("分集")
                    .font(.headline)
                Text("全 \(pages.count) 集")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: showAll) {
                    Label("全部", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(pages) { page in
                        VideoDetailUserAnimeEpisodeTile(
                            page: page,
                            isSelected: page.cid == selectedCID,
                            action: { selectPage(page) }
                        )
                    }
                }
            }
            .padding(.horizontal, -16)
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
    }
}

private struct VideoDetailUserAnimeEpisodeTile: View {
    let page: VideoPage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text("第 \(page.page ?? 1) 集")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(width: 132, height: 68, alignment: .topLeading)
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.3 : 0.7)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
    }

    private var title: String {
        let value = page.part?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "正片" : value
    }
}

private struct VideoDetailUserAnimeEpisodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pages: [VideoPage]
    let selectedCID: Int?
    let selectPage: (VideoPage) -> Void

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(pages) { page in
                        VideoDetailUserAnimeEpisodeTile(
                            page: page,
                            isSelected: page.cid == selectedCID
                        ) {
                            dismiss()
                            if page.cid != selectedCID { selectPage(page) }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("全部分集")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
