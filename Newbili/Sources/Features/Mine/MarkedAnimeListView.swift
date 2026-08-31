import SwiftUI

struct MarkedAnimeListView: View {
    @ObservedObject var libraryStore: LibraryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingUndoSnapshot: MarkedAnimeSnapshot?
    @State private var undoDismissTask: Task<Void, Never>?

    var body: some View {
        List {
            if libraryStore.markedAnimeSnapshots.isEmpty {
                ContentUnavailableView(
                    "还没有追更项目",
                    systemImage: "sparkles.tv",
                    description: Text("打开视频播放器的更多菜单，选择“标记为番剧”即可加入。")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(libraryStore.markedAnimeSnapshots) { snapshot in
                        HStack(spacing: 8) {
                            VideoRouteLink(snapshot.videoItem, showsPressFeedback: true) {
                                MarkedAnimeRow(snapshot: snapshot)
                            }

                            Menu {
                                Button(role: .destructive) {
                                    removeFromTracking(snapshot)
                                } label: {
                                    Label("取消追更", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("管理《\(snapshot.title)》")
                            .accessibilityHint("可取消追更")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                removeFromTracking(snapshot)
                            } label: {
                                Label("取消追更", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("更新检查受 iOS 后台刷新策略限制；打开 App 或回到前台时也会检查。")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let pendingUndoSnapshot {
                undoBar(for: pendingUndoSnapshot)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .tint(libraryStore.appTintColor)
        .navigationTitle("我的追更")
        .navigationBarTitleDisplayMode(.inline)
        .nativeTopScrollEdgeEffect(hidesRootNavigationTitle: false)
        .onDisappear {
            undoDismissTask?.cancel()
        }
    }

    private func undoBar(for snapshot: MarkedAnimeSnapshot) -> some View {
        HStack(spacing: 12) {
            Text("已取消《\(snapshot.title)》追更")
                .font(.footnote.weight(.medium))
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("撤销") {
                undoRemoval()
            }
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func removeFromTracking(_ snapshot: MarkedAnimeSnapshot) {
        undoDismissTask?.cancel()
        libraryStore.setVideoMarkedAsAnime(snapshot.bvid, isMarked: false)
        withAnimation(AppMotion.feedback(reduceMotion: reduceMotion)) {
            pendingUndoSnapshot = snapshot
        }
        let bvid = snapshot.bvid
        undoDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                return
            }
            guard pendingUndoSnapshot?.bvid == bvid else { return }
            withAnimation(AppMotion.feedback(reduceMotion: reduceMotion)) {
                pendingUndoSnapshot = nil
            }
        }
    }

    private func undoRemoval() {
        guard let snapshot = pendingUndoSnapshot else { return }
        undoDismissTask?.cancel()
        libraryStore.restoreMarkedAnimeSnapshot(snapshot)
        withAnimation(AppMotion.feedback(reduceMotion: reduceMotion)) {
            pendingUndoSnapshot = nil
        }
    }
}

private struct MarkedAnimeRow: View {
    let snapshot: MarkedAnimeSnapshot

    var body: some View {
        HStack(spacing: 11) {
            CachedRemoteImage(
                url: thumbnailURL,
                fallbackURL: fallbackURL,
                targetPixelSize: 320
            ) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.14)
                    .overlay { Image(systemName: "sparkles.tv").foregroundStyle(.secondary) }
            }
            .frame(width: 104, height: 65)
            .videoCoverSurface(cornerRadius: 9, shadowLevel: .subtle)

            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let ownerName = snapshot.ownerName, !ownerName.isEmpty {
                    Text(ownerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    Label("\(snapshot.pages.count) P", systemImage: "rectangle.stack")
                    Text(lastCheckedText)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private var thumbnailURL: URL? {
        guard let normalizedURL = snapshot.coverURL?.normalizedBiliURL() else { return nil }
        return URL(string: normalizedURL.biliCoverThumbnailURL(width: 320, height: 200))
    }

    private var fallbackURL: URL? {
        guard let normalizedURL = snapshot.coverURL?.normalizedBiliURL() else { return nil }
        return URL(string: normalizedURL)
    }

    private var lastCheckedText: String {
        guard let lastCheckedAt = snapshot.lastCheckedAt else { return "等待首次检查" }
        return "检查于 \(lastCheckedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
