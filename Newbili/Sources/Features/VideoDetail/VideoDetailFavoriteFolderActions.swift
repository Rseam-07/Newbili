import Foundation

extension VideoDetailViewModel {
    var currentInteractionAccount: FavoriteFolderAccount? {
        let snapshot = sessionStore.credentialSnapshot(for: .interaction,
            multiAccountEnabled: libraryStore.multiAccountExperimentEnabled)
        guard snapshot.isLoggedIn, let mid = snapshot.accountMID else { return nil }
        return FavoriteFolderAccount(mid: mid, version: snapshot.version)
    }

    func invalidateFavoriteFoldersIfAccountChanged() {
        guard favoriteFolderAccount != nil, favoriteFolderAccount != currentInteractionAccount else { return }
        favoriteFolderRequestID = nil
        favoriteFolderAccount = nil
        favoriteFolders = []
        favoriteFolderState = .failed("账号已切换，请重新加载收藏夹")
    }

    func loadFavoriteFoldersForCurrentVideo(forceRefresh: Bool = false) async {
        guard !isPlaybackInvalidatedForNavigation else { return }
        guard let aid = detail.aid else {
            favoriteFolderState = .failed("没有找到视频 AV 号，无法读取收藏夹")
            return
        }
        guard let account = currentInteractionAccount else {
            favoriteFolderRequestID = nil
            favoriteFolderAccount = nil
            favoriteFolders = []
            favoriteFolderState = .failed("请先登录后再查看收藏夹")
            return
        }
        let bvid = detail.bvid
        if favoriteFolderAccount == account {
            if !forceRefresh, favoriteFolderState == .loaded || favoriteFolderState.isLoading { return }
        } else {
            favoriteFolders = []
        }
        let requestID = UUID()
        favoriteFolderRequestID = requestID
        favoriteFolderAccount = account
        favoriteFolderState = .loading
        defer { if favoriteFolderRequestID == requestID { favoriteFolderRequestID = nil } }
        do {
            let folders = try await api.fetchFavoriteFolders(for: aid, account: account)
            guard favoriteFolderRequestID == requestID,
                  currentInteractionAccount == account, !isPlaybackInvalidatedForNavigation,
                  isCurrentVideoContext(aid: aid, bvid: bvid) else { return }
            try Task.checkCancellation()
            favoriteFolders = folders
            favoriteFolderState = .loaded
            interactionState.isFavorited = folders.contains(where: \.isFavorited)
        } catch {
            guard favoriteFolderRequestID == requestID, currentInteractionAccount == account,
                  !isPlaybackInvalidatedForNavigation, isCurrentVideoContext(aid: aid, bvid: bvid) else { return }
            // A refresh failure must not erase the user's pending choices.
            favoriteFolderState = Task.isCancelled || error is CancellationError ? .idle : .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func setFavoriteFolders(selectedIDs: Set<Int>) async -> Bool {
        guard !isPlaybackInvalidatedForNavigation, !isMutatingFavorite else { return false }
        guard let aid = detail.aid else {
            interactionMessage = "没有找到视频 AV 号，无法收藏"
            return false
        }
        guard let account = favoriteFolderAccount, account == currentInteractionAccount,
              favoriteFolderState == .loaded else {
            interactionMessage = "收藏夹身份或内容已变化，请重新加载后再保存"
            return false
        }
        let availableIDs = Set(favoriteFolders.map(\.id))
        guard selectedIDs.isSubset(of: availableIDs) else {
            interactionMessage = "部分收藏夹已失效，请刷新后重新选择"
            return false
        }
        let bvid = detail.bvid
        let currentIDs = Set(favoriteFolders.filter(\.isFavorited).map(\.id))
        let addIDs = selectedIDs.subtracting(currentIDs)
        let removeIDs = currentIDs.subtracting(selectedIDs)
        guard !addIDs.isEmpty || !removeIDs.isEmpty else { return true }
        favoriteFolderRequestID = nil
        interactionMetadataRefreshTask?.cancel()
        interactionMetadataRefreshTask = nil
        setInteractionMutationActive(true, for: .favorite)
        interactionMutationRevision += 1
        interactionMessage = nil
        defer { if !isPlaybackInvalidatedForNavigation { setInteractionMutationActive(false, for: .favorite) } }
        do {
            try await api.setVideoFavorite(aid: aid, addFolderIDs: addIDs, removeFolderIDs: removeIDs, account: account)
            // A server acknowledgement is success, even if navigation or an
            // account switch occurred during the request. Never invite a resend.
            guard currentInteractionAccount == account, !isPlaybackInvalidatedForNavigation,
                  isCurrentVideoContext(aid: aid, bvid: bvid) else { return true }
            interactionMutationRevision += 1
            favoriteFolders = favoriteFolders.map { folder in
                var updated = folder
                updated.favState = selectedIDs.contains(folder.id) ? 1 : 0
                return updated
            }
            favoriteFolderState = .loaded
            interactionState.isFavorited = !selectedIDs.isEmpty
            interactionMessage = selectedIDs.isEmpty ? "已取消收藏" : "已更新收藏夹"
            scheduleAcknowledgedInteractionMetadataRefresh()
            // Refresh counts and metadata when the picker opens again. Saving
            // need not wait for unrelated video and profile requests.
            return true
        } catch {
            guard currentInteractionAccount == account, !isPlaybackInvalidatedForNavigation,
                  isCurrentVideoContext(aid: aid, bvid: bvid) else { return false }
            interactionMessage = interactionFailureMessage(error)
            return false
        }
    }
}
