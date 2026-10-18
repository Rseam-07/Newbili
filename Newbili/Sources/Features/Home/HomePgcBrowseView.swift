import Combine
import SwiftUI

struct HomePgcBrowseView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.openPgcSeasonRouteAction) private var openPgcSeasonRoute
    @StateObject private var viewModel: HomePgcBrowseViewModel
    @State private var selectedTimelineDayID: String?

    let kind: HomePgcKind

    init(kind: HomePgcKind) {
        self.kind = kind
        _viewModel = StateObject(wrappedValue: HomePgcBrowseViewModel(kind: kind))
    }

    var body: some View {
        ZStack {
            HomePgcBackdrop(kind: kind)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    filtersSection

                    if let featured = viewModel.items.first {
                        PgcFeaturedHeroCard(item: featured, kind: kind, open: open)
                            .padding(.horizontal, 16)
                    }

                    if kind == .bangumi, !viewModel.timeline.isEmpty {
                        timelineSection
                    }

                    pgcGridSection

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else if viewModel.canLoadMore {
                        VStack(spacing: 8) {
                            if let error = viewModel.loadMoreError {
                                Text(error).font(.caption).foregroundStyle(.secondary)
                            }
                            Button(viewModel.loadMoreError == nil ? "加载更多" : "重试加载更多") {
                                Task { await viewModel.loadMore(api: dependencies.api) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
            .refreshable {
                await viewModel.refresh(api: dependencies.api)
            }

            if viewModel.items.isEmpty {
                stateOverlay
            }
        }
        .task(id: kind) {
            await viewModel.loadInitial(api: dependencies.api)
            selectDefaultTimelineDay()
        }
        .onChange(of: viewModel.timeline) { _, _ in
            selectDefaultTimelineDay()
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("筛选与排序", systemImage: "line.3.horizontal.decrease")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if viewModel.hasActiveFilters {
                    Button("重置") { Task { await viewModel.resetFilters(api: dependencies.api) } }
                        .font(.subheadline)
                }
            }
            if let conditions = viewModel.conditions {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        if !conditions.order.isEmpty {
                            Menu {
                                ForEach(conditions.order) { order in
                                    Button {
                                        Task { await viewModel.selectFilter(field: "order", value: order.field, api: dependencies.api) }
                                    } label: {
                                        Label(order.name, systemImage: order.field == viewModel.selectedValue(for: "order") ? "checkmark" : "arrow.up.arrow.down")
                                    }
                                }
                            } label: {
                                Text(conditions.order.first(where: { $0.field == viewModel.selectedValue(for: "order") })?.name ?? "排序")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("作品排序")
                        }
                        ForEach(conditions.filters) { filter in
                            Menu {
                                ForEach(filter.values) { value in
                                    Button {
                                        Task { await viewModel.selectFilter(field: filter.field, value: value.keyword, api: dependencies.api) }
                                    } label: {
                                        Label(value.name, systemImage: value.keyword == viewModel.selectedValue(for: filter.field) ? "checkmark" : "line.3.horizontal.decrease")
                                    }
                                }
                            } label: {
                                Text("\(filter.name)：\(filter.values.first(where: { $0.keyword == viewModel.selectedValue(for: filter.field) })?.name ?? "全部")")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("\(filter.name)筛选")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else if viewModel.conditionState.isLoading {
                ProgressView("正在加载筛选条件").font(.caption)
            } else if case .failed = viewModel.conditionState {
                Button("重新加载筛选条件") { viewModel.loadConditions(api: dependencies.api) }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
            }
            if kind == .bangumi, case .failed = viewModel.timelineState {
                Button("重新加载更新日历") { viewModel.loadTimeline(api: dependencies.api) }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
    }

    private var pgcGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(kind == .bangumi ? "热门番剧" : "热门影视")
                    .font(.title2.bold())
                Spacer()
                if let total = viewModel.total, total > 0 {
                    Text("共 \(BiliFormatters.compactCount(total)) 部")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104, maximum: 132), spacing: 11)],
                alignment: .leading,
                spacing: 18
            ) {
                ForEach(viewModel.items.dropFirst()) { item in
                    PgcPosterGridCard(item: item, open: open)
                        .onAppear {
                            guard item.id == viewModel.items.last?.id else { return }
                            Task { await viewModel.loadMore(api: dependencies.api) }
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("更新日历", systemImage: "calendar.badge.clock")
                    .font(.title3.bold())
                Spacer()
                Text("近期更新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(viewModel.timeline) { day in
                        Button {
                            withAnimation(.smooth(duration: 0.2)) {
                                selectedTimelineDayID = day.id
                            }
                        } label: {
                            PgcTimelineDayChip(
                                day: day,
                                isSelected: selectedTimelineDayID == day.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)

            if let selectedTimelineDay {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(selectedTimelineDay.episodes) { episode in
                            if episode.published {
                                PgcTimelineEpisodeCard(episode: episode, open: open)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.state {
        case .failed(let message):
            ContentUnavailableView {
                Label("暂时无法加载\(kind.title)", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("重试") {
                    Task { await viewModel.refresh(api: dependencies.api) }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loading, .idle:
            ProgressView("正在加载\(kind.title)")
        case .loaded:
            ContentUnavailableView("暂无内容", systemImage: "sparkles.tv")
        }
    }

    private var selectedTimelineDay: PgcTimelineDay? {
        viewModel.timeline.first { $0.id == selectedTimelineDayID }
            ?? viewModel.timeline.first(where: \.isToday)
            ?? viewModel.timeline.first
    }

    private func selectDefaultTimelineDay() {
        guard selectedTimelineDayID == nil || !viewModel.timeline.contains(where: { $0.id == selectedTimelineDayID }) else {
            return
        }
        selectedTimelineDayID = viewModel.timeline.first(where: \.isToday)?.id
            ?? viewModel.timeline.first?.id
    }

    private func open(_ route: PgcSeasonRoute?) {
        guard let route else { return }
        openPgcSeasonRoute?(route)
    }
}

private struct PgcFeaturedHeroCard: View {
    let item: PgcBrowseItem
    let kind: HomePgcKind
    let open: (PgcSeasonRoute?) -> Void

    var body: some View {
        Button { open(item.route) } label: {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    CachedRemoteImage(
                        url: (item.cover?.normalizedBiliURL()).flatMap { URL(string: $0) },
                        targetPixelSize: 1_000,
                        animatesAppearance: false
                    ) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        LinearGradient(
                            colors: [.pink.opacity(0.5), .blue.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.84)],
                    startPoint: UnitPoint(x: 0.5, y: 0.32),
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Label(kind.title, systemImage: kind == .bangumi ? "sparkles.tv" : "film.stack")
                        if let badge = item.badge, !badge.isEmpty {
                            Text(badge)
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.88))

                    Text(item.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 9) {
                        if let score = item.score, !score.isEmpty {
                            Label("\(score) 分", systemImage: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                        if let order = item.order, !order.isEmpty {
                            Text(order)
                        }
                        if let indexShow = item.indexShow, !indexShow.isEmpty {
                            Text(indexShow)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 286)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.20), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开\(kind.title) \(item.title)")
    }
}

private struct PgcPosterGridCard: View {
    let item: PgcBrowseItem
    let open: (PgcSeasonRoute?) -> Void

    var body: some View {
        Button { open(item.route) } label: {
            VStack(alignment: .leading, spacing: 6) {
                poster
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.90))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 31, alignment: .topLeading)
                if let indexShow = item.indexShow, !indexShow.isEmpty {
                    Text(indexShow)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var poster: some View {
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
        .overlay(alignment: .topLeading) {
            if let badge = item.badge, !badge.isEmpty {
                Text(badge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(7)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let score = item.score, !score.isEmpty {
                Label(score, systemImage: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(7)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 11, y: 6)
    }
}

private struct PgcTimelineEpisodeCard: View {
    let episode: PgcTimelineEpisode
    let open: (PgcSeasonRoute?) -> Void

    var body: some View {
        Button { open(episode.route) } label: {
            VStack(alignment: .leading, spacing: 6) {
                CachedRemoteImage(
                    url: ((episode.episodeCover ?? episode.cover)?.normalizedBiliURL())
                        .flatMap { URL(string: $0) },
                    targetPixelSize: 360,
                    animatesAppearance: false
                ) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    BiliMediaPlaceholder(style: .video, iconSize: 20)
                }
                .frame(width: 132, height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 10, y: 5)

                Text(episode.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(width: 132, alignment: .leading)

                Text([episode.publishTime, episode.publishIndex].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 132, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PgcTimelineDayChip: View {
    let day: PgcTimelineDay
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(day.displayDate)
                .font(.subheadline.weight(.semibold))
            Text(day.date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 13)
        .frame(height: 48)
        .background {
            Capsule()
                .fill(isSelected ? Color.primary.opacity(0.12) : Color.clear)
                .biliPlayerClearGlass(
                    interactive: true,
                    in: Capsule(),
                    isEnabled: isSelected
                )
        }
    }
}

private struct HomePgcBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(HomeRealtimeBlurSettings.storageKey)
    private var realtimeAmbientBlurEnabled = HomeRealtimeBlurSettings.defaultIsEnabled
    let kind: HomePgcKind

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? AppSurfaceColors.darkHomeGradient
                    : [Color(red: 0.97, green: 0.98, blue: 1), Color(red: 1, green: 0.96, blue: 0.97), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if realtimeAmbientBlurEnabled {
                Circle()
                    .fill((kind == .bangumi ? Color.pink : Color.orange).opacity(colorScheme == .dark ? 0.14 : 0.20))
                    .frame(width: 330, height: 330)
                    .blur(radius: 72)
                    .offset(x: -150, y: -230)

                Circle()
                    .fill(Color.cyan.opacity(colorScheme == .dark ? 0.09 : 0.15))
                    .frame(width: 360, height: 360)
                    .blur(radius: 78)
                    .offset(x: 150, y: 260)
            } else {
                HomeAmbientGradientGlow(
                    color: kind == .bangumi ? .pink : .orange,
                    innerOpacity: colorScheme == .dark ? 0.14 : 0.20,
                    middleOpacity: colorScheme == .dark ? 0.05 : 0.09,
                    endRadius: 235
                )
                .frame(width: 470, height: 470)
                .offset(x: -150, y: -230)

                HomeAmbientGradientGlow(
                    color: .cyan,
                    innerOpacity: colorScheme == .dark ? 0.09 : 0.15,
                    middleOpacity: colorScheme == .dark ? 0.035 : 0.07,
                    endRadius: 255
                )
                .frame(width: 510, height: 510)
                .offset(x: 150, y: 260)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
