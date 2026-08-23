import Combine
import SwiftUI

struct HomeRegionRankingView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.openPgcSeasonRouteAction) private var openPgcSeasonRoute
    @StateObject private var viewModel = HomeRegionRankingViewModel()
    @State private var selectedRegion = HomeRegionDefinition.all

    var body: some View {
        HStack(spacing: 0) {
            regionRail
            Divider().opacity(0.55)
            rankingContent
        }
        .background(Color(.systemBackground))
        .task(id: selectedRegion.id) {
            await viewModel.load(region: selectedRegion, api: dependencies.api)
        }
    }

    private var regionRail: some View {
        ScrollView {
            LazyVStack(spacing: 7) {
                ForEach(HomeRegionDefinition.allCases) { region in
                    Button {
                        withAnimation(.smooth(duration: 0.2)) {
                            selectedRegion = region
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: region.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                            Text(region.title)
                                .font(.caption.weight(selectedRegion == region ? .bold : .medium))
                        }
                        .foregroundStyle(selectedRegion == region ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background {
                            if selectedRegion == region {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.primary.opacity(0.09))
                                    .biliPlayerClearGlass(
                                        interactive: true,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(region.title)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 10)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .frame(width: 76)
        .background(.ultraThinMaterial.opacity(0.55))
    }

    private var rankingContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedRegion.title)
                            .font(.title2.bold())
                        Text("全站排行榜")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await viewModel.load(region: selectedRegion, api: dependencies.api, force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .biliPlayerClearGlass(interactive: true, in: Circle())
                    .accessibilityLabel("刷新\(selectedRegion.title)")
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                contentBody
            }
            .padding(.bottom, 120)
        }
        .refreshable {
            await viewModel.load(region: selectedRegion, api: dependencies.api, force: true)
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if !viewModel.videos.isEmpty {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132, maximum: 190), spacing: 12)],
                alignment: .leading,
                spacing: 17
            ) {
                ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                    HomeRegionVideoCard(video: video, rank: index + 1)
                }
            }
            .padding(.horizontal, 12)
        } else if !viewModel.pgcItems.isEmpty {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104, maximum: 145), spacing: 12)],
                alignment: .leading,
                spacing: 17
            ) {
                ForEach(Array(viewModel.pgcItems.enumerated()), id: \.element.id) { index, item in
                    HomeRegionPgcCard(item: item, rank: index + 1) {
                        guard let route = item.route else { return }
                        openPgcSeasonRoute?(route)
                    }
                }
            }
            .padding(.horizontal, 12)
        } else {
            stateView
                .frame(maxWidth: .infinity)
                .padding(.top, 90)
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.state {
        case .failed(let message):
            ContentUnavailableView {
                Label("分区加载失败", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("重试") {
                    Task { await viewModel.load(region: selectedRegion, api: dependencies.api, force: true) }
                }
            }
        case .loaded:
            ContentUnavailableView("暂无排行", systemImage: "chart.bar")
        case .idle, .loading:
            ProgressView("正在加载排行")
        }
    }
}

private enum HomeRegionDefinition: String, CaseIterable, Identifiable, Hashable {
    case all, bangumi, guochuang, animation, music, dance, game, knowledge, tech
    case sports, car, food, animal, kichiku, fashion, entertainment, cinephile
    case documentary, movie, tv, variety

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全站"
        case .bangumi: "番剧"
        case .guochuang: "国创"
        case .animation: "动画"
        case .music: "音乐"
        case .dance: "舞蹈"
        case .game: "游戏"
        case .knowledge: "知识"
        case .tech: "科技"
        case .sports: "运动"
        case .car: "汽车"
        case .food: "美食"
        case .animal: "动物"
        case .kichiku: "鬼畜"
        case .fashion: "时尚"
        case .entertainment: "娱乐"
        case .cinephile: "影视"
        case .documentary: "纪录"
        case .movie: "电影"
        case .tv: "剧集"
        case .variety: "综艺"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "chart.bar.xaxis"
        case .bangumi: "sparkles.tv"
        case .guochuang: "paintbrush.pointed"
        case .animation: "scribble.variable"
        case .music: "music.note"
        case .dance: "figure.dance"
        case .game: "gamecontroller"
        case .knowledge: "book.closed"
        case .tech: "cpu"
        case .sports: "figure.run"
        case .car: "car"
        case .food: "fork.knife"
        case .animal: "pawprint"
        case .kichiku: "waveform"
        case .fashion: "tshirt"
        case .entertainment: "party.popper"
        case .cinephile: "film.stack"
        case .documentary: "camera.aperture"
        case .movie: "film"
        case .tv: "tv"
        case .variety: "theatermasks"
        }
    }

    var regionID: Int? {
        switch self {
        case .all: 0
        case .animation: 1005
        case .music: 1003
        case .dance: 1004
        case .game: 1008
        case .knowledge: 1010
        case .tech: 1012
        case .sports: 1018
        case .car: 1013
        case .food: 1020
        case .animal: 1024
        case .kichiku: 1007
        case .fashion: 1014
        case .entertainment: 1002
        case .cinephile: 1001
        case .bangumi, .guochuang, .documentary, .movie, .tv, .variety: nil
        }
    }

    var pgcSeasonType: Int? {
        switch self {
        case .bangumi: 1
        case .movie: 2
        case .documentary: 3
        case .guochuang: 4
        case .tv: 5
        case .variety: 7
        default: nil
        }
    }
}

@MainActor
private final class HomeRegionRankingViewModel: ObservableObject {
    @Published private(set) var videos: [VideoItem] = []
    @Published private(set) var pgcItems: [PgcRankItem] = []
    @Published private(set) var state: LoadingState = .idle

    private var loadedRegionID: String?
    private var generation = 0

    func load(region: HomeRegionDefinition, api: BiliAPIClient, force: Bool = false) async {
        guard force || loadedRegionID != region.id else { return }
        generation += 1
        let currentGeneration = generation
        state = .loading
        videos = []
        pgcItems = []

        do {
            if let regionID = region.regionID {
                let result = try await api.fetchRankingVideos(regionID: regionID)
                guard currentGeneration == generation, !Task.isCancelled else { return }
                videos = result
            } else if let seasonType = region.pgcSeasonType {
                let result = try await api.fetchPgcRanking(seasonType: seasonType)
                guard currentGeneration == generation, !Task.isCancelled else { return }
                pgcItems = result
            }
            loadedRegionID = region.id
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard currentGeneration == generation else { return }
            state = .failed(error.localizedDescription)
        }
    }
}

private struct HomeRegionVideoCard: View {
    let video: VideoItem
    let rank: Int

    var body: some View {
        VideoRouteLink(video) {
            VStack(alignment: .leading, spacing: 7) {
                CachedRemoteImage(
                    url: (video.pic?.normalizedBiliURL()).flatMap { URL(string: $0) },
                    targetPixelSize: 520,
                    animatesAppearance: false
                ) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    BiliMediaPlaceholder(style: .video, iconSize: 20)
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("#\(rank)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(rank <= 3 ? Color.pink.opacity(0.88) : Color.black.opacity(0.50), in: Capsule())
                        .padding(7)
                }
                .shadow(color: .black.opacity(0.14), radius: 8, y: 4)

                Text(video.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Label(BiliFormatters.compactCount(video.stat?.view), systemImage: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HomeRegionPgcCard: View {
    let item: PgcRankItem
    let rank: Int
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 7) {
                CachedRemoteImage(
                    url: (item.cover?.normalizedBiliURL()).flatMap { URL(string: $0) },
                    targetPixelSize: 420,
                    animatesAppearance: false
                ) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    BiliMediaPlaceholder(style: .video, iconSize: 22)
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("#\(rank)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(rank <= 3 ? Color.pink.opacity(0.88) : Color.black.opacity(0.50), in: Capsule())
                        .padding(7)
                }
                .shadow(color: .black.opacity(0.16), radius: 9, y: 5)

                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(item.newEpisode?.indexShow ?? BiliFormatters.compactCount(item.stat?.follow) + " 追番")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
