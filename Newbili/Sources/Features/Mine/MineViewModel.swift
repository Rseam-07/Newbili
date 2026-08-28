import Foundation
import Combine

@MainActor
final class MineViewModel: ObservableObject {
    @Published var state: LoadingState = .idle
    @Published var loginMessage = ""
    @Published var qrLoginState: QRCodeLoginState = .idle
    @Published var historyState: LoadingState = .idle
    @Published var favoriteState: LoadingState = .idle
    @Published var watchLaterState: LoadingState = .idle
    @Published private(set) var watchLaterLoadMoreState: LoadingState = .idle
    @Published private(set) var watchLaterMutationState: LoadingState = .idle
    @Published private(set) var watchLaterHasMore = false
    @Published private(set) var watchLaterTotalCount = 0
    @Published var watchLaterEntries: [AccountVideoEntry] = []
    @Published private(set) var historyLoadMoreState: LoadingState = .idle
    @Published private(set) var historyHasMore = false
    @Published var accountHistory: [AccountVideoEntry] = []
    @Published var favoriteFolders: [FavoriteFolder] = []
    @Published var favoriteFolderEntries: [Int: [AccountVideoEntry]] = [:]
    @Published var favoriteFolderEntryStates: [Int: LoadingState] = [:]
    @Published private(set) var favoriteFolderLoadMoreStates: [Int: LoadingState] = [:]
    @Published private(set) var favoriteFolderHasMore: [Int: Bool] = [:]

    private let api: BiliAPIClient
    private let sessionStore: SessionStore
    private let navUserLoader: () async throws -> NavUserInfo
    private var qrLoginTask: Task<Void, Never>?
    private var refreshingUserMID: Int?
    private var userRefreshGeneration = 0
    private let accountLibraryPageSize = 20
    private var historyRequestGeneration = 0
    private var favoriteRequestGeneration = 0
    private var favoriteFolderRequestGenerations: [Int: Int] = [:]
    private var historyCursor: AccountHistoryCursor?
    private var favoriteFolderPages: [Int: Int] = [:]
    private var watchLaterPage = 1
    private var watchLaterActiveQuery = WatchLaterQuery.defaultQuery
    private var watchLaterLoadedQuery: WatchLaterQuery?
    private var watchLaterRequestGeneration = 0

    init(
        api: BiliAPIClient,
        sessionStore: SessionStore,
        navUserLoader: (() async throws -> NavUserInfo)? = nil
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.navUserLoader = navUserLoader ?? { try await api.fetchNavUser() }
    }

    func refreshUser() async {
        guard sessionStore.isLoggedIn,
              let requestedMID = sessionStore.mainAccountMID
        else {
            state = .idle
            return
        }
        // Login completion and Mine's credential-version task can arrive in the
        // same run-loop turn. Coalesce work for one account, but let a newly
        // selected main account supersede an older request immediately.
        if refreshingUserMID == requestedMID {
            return
        }
        userRefreshGeneration &+= 1
        let generation = userRefreshGeneration
        refreshingUserMID = requestedMID
        state = .loading
        defer {
            if userRefreshGeneration == generation {
                refreshingUserMID = nil
                if state.isLoading {
                    state = sessionStore.user == nil ? .idle : .loaded
                }
            }
        }
        do {
            let user = try await navUserLoader()
            guard !Task.isCancelled,
                  userRefreshGeneration == generation,
                  sessionStore.mainAccountMID == requestedMID
            else { return }
            if user.isLogin == true {
                if let responseMID = user.mid, responseMID != requestedMID {
                    state = .failed("账号资料与当前主账号不一致，请重试")
                    return
                }
                sessionStore.updateAccountUser(mid: requestedMID, user: user)
                state = .loaded
            } else {
                try? sessionStore.logout()
                resetAccountLibraryState()
                state = .idle
                loginMessage = "登录已失效，请重新登录"
            }
        } catch {
            guard userRefreshGeneration == generation,
                  sessionStore.mainAccountMID == requestedMID
            else { return }
            if Task.isCancelled {
                state = sessionStore.user == nil ? .idle : .loaded
            } else {
                // Keep the last successful profile (including level/experience)
                // visible and expose an explicit retry instead of replacing it
                // with an empty "UID 0" shell after a transient network error.
                state = .failed(error.localizedDescription)
            }
        }
    }

    func loadAccountLibrary(
        _ request: AccountLibraryLoadRequest,
        policy: AccountLibraryLoadPolicy = .ifNeeded
    ) async {
        guard sessionStore.isLoggedIn else { return }

        if let query = request.watchLaterQuery {
            switch policy {
            case .ifNeeded:
                guard shouldLoadWatchLater(query) else { return }
            case .reload:
                guard !watchLaterState.isLoading || watchLaterActiveQuery != query else { return }
            }
            await refreshWatchLater(query)
            return
        }

        let currentState = accountLibraryState(for: request)
        switch policy {
        case .ifNeeded:
            guard currentState == .idle else { return }
        case .reload:
            guard !currentState.isLoading else { return }
        }

        switch request {
        case .history:
            await refreshHistory()
        case .favorites:
            await refreshFavorites()
        case .watchLater:
            assertionFailure("Watch Later requests are handled before generic libraries")
        case .favoriteFolder(let id):
            await refreshFavoriteFolder(id: id)
        }
    }

    func invalidateAccountLibraries(_ requests: [AccountLibraryLoadRequest]) {
        for request in requests {
            switch request {
            case .history:
                historyRequestGeneration &+= 1
                accountHistory = []
                historyState = .idle
                historyLoadMoreState = .idle
                historyHasMore = false
                historyCursor = nil
            case .favorites:
                favoriteRequestGeneration &+= 1
                favoriteFolders = []
                favoriteState = .idle
                let folderIDs = Set(favoriteFolderRequestGenerations.keys)
                    .union(favoriteFolderEntryStates.keys)
                    .union(favoriteFolderEntries.keys)
                for id in folderIDs {
                    favoriteFolderRequestGenerations[id, default: 0] &+= 1
                }
                favoriteFolderEntries = [:]
                favoriteFolderEntryStates = [:]
                favoriteFolderLoadMoreStates = [:]
                favoriteFolderHasMore = [:]
                favoriteFolderPages = [:]
            case .watchLater:
                watchLaterRequestGeneration &+= 1
                watchLaterEntries = []
                watchLaterState = .idle
                watchLaterLoadMoreState = .idle
                watchLaterMutationState = .idle
                watchLaterHasMore = false
                watchLaterTotalCount = 0
                watchLaterPage = 1
                watchLaterActiveQuery = .defaultQuery
                watchLaterLoadedQuery = nil
            case .favoriteFolder(let id):
                favoriteFolderRequestGenerations[id, default: 0] &+= 1
                favoriteFolderEntries[id] = nil
                favoriteFolderEntryStates[id] = nil
                favoriteFolderLoadMoreStates[id] = nil
                favoriteFolderHasMore[id] = nil
                favoriteFolderPages[id] = nil
            }
        }
    }

    private func accountLibraryState(for request: AccountLibraryLoadRequest) -> LoadingState {
        switch request {
        case .history:
            return historyState
        case .favorites:
            return favoriteState
        case .watchLater:
            return watchLaterState
        case .favoriteFolder(let id):
            return favoriteFolderEntryStates[id] ?? .idle
        }
    }

    private func shouldLoadWatchLater(_ query: WatchLaterQuery) -> Bool {
        if watchLaterState.isLoading, watchLaterActiveQuery == query {
            return false
        }
        return watchLaterState != .loaded || watchLaterLoadedQuery != query
    }

    private func refreshHistory() async {
        guard sessionStore.isLoggedIn else { return }
        historyRequestGeneration &+= 1
        let generation = historyRequestGeneration
        historyState = .loading
        historyLoadMoreState = .idle
        historyCursor = nil
        historyHasMore = false
        do {
            let page = try await api.fetchAccountHistoryPage(pageSize: accountLibraryPageSize)
            guard generation == historyRequestGeneration else { return }
            accountHistory = Self.uniqued(page.entries)
            historyCursor = page.nextHistoryCursor
            historyHasMore = page.hasMore
            historyState = .loaded
        } catch {
            guard generation == historyRequestGeneration else { return }
            historyState = .failed(error.localizedDescription)
        }
    }

    private func refreshFavorites() async {
        guard sessionStore.isLoggedIn else { return }
        favoriteRequestGeneration &+= 1
        let generation = favoriteRequestGeneration
        favoriteState = .loading
        do {
            let folders = try await api.fetchFavoriteFolders()
            guard generation == favoriteRequestGeneration else { return }
            favoriteFolders = folders
            favoriteState = .loaded
        } catch {
            guard generation == favoriteRequestGeneration else { return }
            favoriteState = .failed(error.localizedDescription)
        }
    }

    private func refreshWatchLater(_ requestedQuery: WatchLaterQuery? = nil) async {
        guard sessionStore.isLoggedIn else { return }
        let query = requestedQuery ?? watchLaterActiveQuery
        let queryChanged = query != watchLaterActiveQuery
        watchLaterActiveQuery = query
        if queryChanged {
            watchLaterEntries = []
            watchLaterTotalCount = 0
            watchLaterLoadedQuery = nil
        }
        watchLaterRequestGeneration &+= 1
        let generation = watchLaterRequestGeneration
        watchLaterState = .loading
        watchLaterLoadMoreState = .idle
        watchLaterHasMore = false
        watchLaterPage = 1
        do {
            let page = try await api.fetchWatchLaterPage(
                page: 1,
                pageSize: accountLibraryPageSize,
                filter: query.filter,
                keyword: query.keyword,
                sortOrder: query.sortOrder
            )
            guard generation == watchLaterRequestGeneration else { return }
            watchLaterEntries = Self.uniqued(page.entries)
            watchLaterTotalCount = page.totalCount
            watchLaterHasMore = page.hasMore
            watchLaterLoadedQuery = query
            watchLaterState = .loaded
        } catch {
            guard generation == watchLaterRequestGeneration else { return }
            watchLaterState = .failed(error.localizedDescription)
        }
    }

    func loadMoreWatchLaterIfNeeded(current item: AccountVideoEntry?) async {
        guard let item, watchLaterEntries.last?.id == item.id else { return }
        await loadMoreWatchLater()
    }

    func loadMoreWatchLater() async {
        guard sessionStore.isLoggedIn,
              watchLaterHasMore,
              !watchLaterState.isLoading,
              !watchLaterLoadMoreState.isLoading
        else { return }
        let nextPage = watchLaterPage + 1
        let generation = watchLaterRequestGeneration
        let query = watchLaterActiveQuery
        watchLaterLoadMoreState = .loading
        do {
            let page = try await api.fetchWatchLaterPage(
                page: nextPage,
                pageSize: accountLibraryPageSize,
                filter: query.filter,
                keyword: query.keyword,
                sortOrder: query.sortOrder
            )
            guard generation == watchLaterRequestGeneration,
                  query == watchLaterActiveQuery
            else { return }
            let previousCount = watchLaterEntries.count
            watchLaterEntries = Self.appendingUnique(page.entries, to: watchLaterEntries)
            watchLaterPage = nextPage
            watchLaterTotalCount = page.totalCount
            watchLaterHasMore = page.hasMore && watchLaterEntries.count > previousCount
            watchLaterLoadMoreState = .idle
        } catch {
            guard generation == watchLaterRequestGeneration else { return }
            watchLaterLoadMoreState = .failed(error.localizedDescription)
        }
    }

    func addToWatchLater(identifier: String) async throws {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw BiliAPIError.api(code: -1, message: "请输入 AV 号或 BV 号")
        }
        watchLaterMutationState = .loading
        do {
            let lowercased = normalized.lowercased()
            if lowercased.hasPrefix("av"), let aid = Int(normalized.dropFirst(2)), aid > 0 {
                try await api.addVideoToWatchLater(aid: aid)
            } else if let aid = Int(normalized), aid > 0 {
                try await api.addVideoToWatchLater(aid: aid)
            } else if lowercased.hasPrefix("bv") {
                try await api.addVideoToWatchLater(bvid: normalized)
            } else {
                throw BiliAPIError.api(code: -1, message: "请输入有效的 AV 号或 BV 号")
            }
            watchLaterMutationState = .loaded
            await refreshWatchLater()
        } catch {
            watchLaterMutationState = .failed(error.localizedDescription)
            throw error
        }
    }

    func removeFromWatchLater(aids: Set<Int>) async throws {
        guard !aids.isEmpty else { return }
        watchLaterMutationState = .loading
        do {
            try await api.removeVideosFromWatchLater(aids: aids)
            watchLaterEntries.removeAll { entry in
                entry.aid.map(aids.contains) == true
            }
            watchLaterTotalCount = max(0, watchLaterTotalCount - aids.count)
            watchLaterMutationState = .loaded
        } catch {
            watchLaterMutationState = .failed(error.localizedDescription)
            throw error
        }
    }

    func clearWatchLater(scope: WatchLaterClearScope) async throws {
        watchLaterMutationState = .loading
        do {
            try await api.clearWatchLater(scope: scope)
            watchLaterMutationState = .loaded
            await refreshWatchLater()
        } catch {
            watchLaterMutationState = .failed(error.localizedDescription)
            throw error
        }
    }

    private func refreshFavoriteFolder(id: Int) async {
        guard sessionStore.isLoggedIn else { return }
        let generation = (favoriteFolderRequestGenerations[id] ?? 0) &+ 1
        favoriteFolderRequestGenerations[id] = generation
        favoriteFolderEntryStates[id] = .loading
        favoriteFolderLoadMoreStates[id] = .idle
        favoriteFolderPages[id] = 1
        favoriteFolderHasMore[id] = false
        do {
            let page = try await api.fetchFavoriteFolderVideoPage(
                folderID: id,
                page: 1,
                pageSize: accountLibraryPageSize
            )
            guard favoriteFolderRequestGenerations[id] == generation else { return }
            favoriteFolderEntries[id] = Self.uniqued(page.entries)
            favoriteFolderHasMore[id] = page.hasMore
            favoriteFolderEntryStates[id] = .loaded
        } catch {
            guard favoriteFolderRequestGenerations[id] == generation else { return }
            favoriteFolderEntryStates[id] = .failed(error.localizedDescription)
        }
    }

    func loadMoreHistoryIfNeeded(current item: AccountVideoEntry?) async {
        guard let item, accountHistory.last?.id == item.id else { return }
        await loadMoreHistory()
    }

    func loadMoreHistory() async {
        guard sessionStore.isLoggedIn,
              historyHasMore,
              !historyState.isLoading,
              !historyLoadMoreState.isLoading
        else { return }
        let generation = historyRequestGeneration
        historyLoadMoreState = .loading
        do {
            let page = try await api.fetchAccountHistoryPage(
                cursor: historyCursor,
                pageSize: accountLibraryPageSize
            )
            guard generation == historyRequestGeneration else { return }
            let previousCount = accountHistory.count
            accountHistory = Self.appendingUnique(page.entries, to: accountHistory)
            historyCursor = page.nextHistoryCursor
            historyHasMore = page.hasMore && accountHistory.count > previousCount
            historyLoadMoreState = .idle
        } catch {
            guard generation == historyRequestGeneration else { return }
            historyLoadMoreState = .failed(error.localizedDescription)
        }
    }

    func loadMoreFavoriteFolderIfNeeded(_ folder: FavoriteFolder, current item: AccountVideoEntry?) async {
        guard let item, favoriteFolderEntries[folder.id]?.last?.id == item.id else { return }
        await loadMoreFavoriteFolder(folder)
    }

    func loadMoreFavoriteFolder(_ folder: FavoriteFolder) async {
        guard sessionStore.isLoggedIn,
              favoriteFolderHasMore[folder.id] == true,
              !(favoriteFolderEntryStates[folder.id]?.isLoading ?? false),
              !(favoriteFolderLoadMoreStates[folder.id]?.isLoading ?? false)
        else { return }
        let generation = favoriteFolderRequestGenerations[folder.id] ?? 0
        let nextPage = (favoriteFolderPages[folder.id] ?? 1) + 1
        favoriteFolderLoadMoreStates[folder.id] = .loading
        do {
            let page = try await api.fetchFavoriteFolderVideoPage(
                folderID: folder.id,
                page: nextPage,
                pageSize: accountLibraryPageSize
            )
            guard favoriteFolderRequestGenerations[folder.id] == generation else { return }
            let previousCount = favoriteFolderEntries[folder.id]?.count ?? 0
            favoriteFolderEntries[folder.id] = Self.appendingUnique(
                page.entries,
                to: favoriteFolderEntries[folder.id] ?? []
            )
            favoriteFolderPages[folder.id] = nextPage
            favoriteFolderHasMore[folder.id] = page.hasMore
                && (favoriteFolderEntries[folder.id]?.count ?? 0) > previousCount
            favoriteFolderLoadMoreStates[folder.id] = .idle
        } catch {
            guard favoriteFolderRequestGenerations[folder.id] == generation else { return }
            favoriteFolderLoadMoreStates[folder.id] = .failed(error.localizedDescription)
        }
    }

    func completeWebLogin(with cookies: [HTTPCookie]) async {
        do {
            cancelQRCodeLogin()
            try sessionStore.saveLoginCookies(cookies, credentialKind: .web)
            loginMessage = "网页登录成功，首页推荐建议优先选择网页端。"
            await refreshUser()
        } catch {
            loginMessage = error.localizedDescription
        }
    }

    func logout() {
        cancelQRCodeLogin()
        userRefreshGeneration &+= 1
        refreshingUserMID = nil
        try? sessionStore.logout()
        BiliWebCookieStore.clearLoginCookies()
        resetAccountLibraryState()
        loginMessage = ""
        qrLoginState = .idle
        state = .idle
    }

    func startQRCodeLogin() async {
        cancelQRCodeLogin()
        qrLoginState = .loading
        loginMessage = ""

        do {
            let info = try await api.generateAppQRCodeLogin()
            guard !Task.isCancelled else { return }
            let autoConfirmMessage: String
            do {
                try await api.confirmAppQRCodeLoginWithCurrentSession(authCode: info.qrcodeKey)
                autoConfirmMessage = ""
            } catch {
                autoConfirmMessage = error.localizedDescription
            }
            guard !Task.isCancelled else { return }
            if autoConfirmMessage.isEmpty {
                qrLoginState = .scanned(info, "已用当前账号确认，正在获取移动端凭证")
            } else {
                qrLoginState = .waiting(info, "自动确认未完成：\(autoConfirmMessage)。可用 B 站扫码或打开确认")
            }
            qrLoginTask = Task { [weak self] in
                await self?.pollQRCodeLogin(info)
            }
        } catch {
            qrLoginState = .failed(error.localizedDescription)
        }
    }

    func cancelQRCodeLogin() {
        qrLoginTask?.cancel()
        qrLoginTask = nil
    }

    func sendAppSMSCode(phone: String, countryCode: String) async throws -> String {
        cancelQRCodeLogin()
        let info = try await api.sendAppSMSCode(
            phone: Self.normalizedPhone(phone),
            countryCode: Self.normalizedCountryCode(countryCode)
        )
        guard let captchaKey = info.captchaKey, !captchaKey.isEmpty else {
            throw BiliAPIError.missingPayload
        }
        return captchaKey
    }

    func completeAppSMSLogin(
        phone: String,
        countryCode: String,
        code: String,
        captchaKey: String
    ) async throws {
        cancelQRCodeLogin()
        let loginData = try await api.loginWithAppSMS(
            phone: Self.normalizedPhone(phone),
            countryCode: Self.normalizedCountryCode(countryCode),
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            captchaKey: captchaKey
        )
        let cookieValues = loginData.loginCookieValues
        guard !cookieValues.isEmpty else {
            throw BiliAPIError.missingPayload
        }
        try sessionStore.saveLoginCookies(cookieValues, credentialKind: .appSMS)
        guard sessionStore.isLoggedIn else {
            throw BiliAPIError.missingSESSDATA
        }
        if sessionStore.appAccessKey() == nil {
            loginMessage = "登录成功，但没有拿到 access_key"
        } else {
            loginMessage = "短信登录成功，App 端推荐会更接近官方客户端。"
        }
        await refreshUser()
    }

    private func pollQRCodeLogin(_ info: QRCodeLoginInfo) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            do {
                let result = try await api.pollAppQRCodeLogin(authCode: info.qrcodeKey)
                switch result.status {
                case .waitingForScan:
                    if case .waiting = qrLoginState {
                        break
                    }
                    qrLoginState = .waiting(info, result.message ?? "请使用 B 站客户端扫码")
                case .waitingForConfirm:
                    qrLoginState = .scanned(info, result.message ?? "已扫码，请在手机上确认")
                case .expired:
                    qrLoginState = .expired(result.message ?? "二维码已过期")
                    return
                case .confirmed:
                    guard let loginData = result.loginData else {
                        qrLoginState = .failed("登录成功但没有拿到移动端凭证，请改用网页登录。")
                        return
                    }
                    let cookieValues = loginData.loginCookieValues
                    guard !cookieValues.isEmpty else {
                        qrLoginState = .failed("登录成功但没有拿到 Cookie，请改用网页登录。")
                        return
                    }
                    try sessionStore.saveLoginCookies(cookieValues, credentialKind: .appQRCodeTV)
                    guard sessionStore.isLoggedIn else {
                        qrLoginState = .failed("登录成功但没有拿到 Cookie，请改用网页登录。")
                        return
                    }
                    if sessionStore.appAccessKey() == nil {
                        loginMessage = "登录成功，但没有拿到 access_key"
                        qrLoginState = .succeeded("登录成功，但移动端凭证缺失")
                    } else {
                        loginMessage = "扫码登录成功；如 App 端推荐不准，可改用短信登录或网页端推荐。"
                        qrLoginState = .succeeded("扫码登录成功")
                    }
                    await refreshUser()
                    return
                case .unknown(let code):
                    let message = result.message ?? "未知状态"
                    qrLoginState = .waiting(info, "\(message) (\(code))")
                }
            } catch {
                if !Task.isCancelled, !Self.isTransientQRCodePollingError(error) {
                    qrLoginState = .waiting(info, error.localizedDescription)
                }
            }
        }
    }

    private nonisolated static func normalizedPhone(_ value: String) -> String {
        value
            .filter { $0.isNumber }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func normalizedCountryCode(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        return digits.isEmpty ? "86" : digits
    }

    private nonisolated static func isTransientQRCodePollingError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        let code = URLError.Code(rawValue: nsError.code)
        switch code {
        case .networkConnectionLost, .notConnectedToInternet, .timedOut, .cancelled:
            return true
        default:
            return false
        }
    }

    private func resetAccountLibraryState() {
        invalidateAccountLibraries([
            .history,
            .favorites,
            .watchLater(filter: .all, keyword: "", sortOrder: .newest)
        ])
    }

    private nonisolated static func uniqued(_ entries: [AccountVideoEntry]) -> [AccountVideoEntry] {
        appendingUnique(entries, to: [])
    }

    private nonisolated static func appendingUnique(
        _ newEntries: [AccountVideoEntry],
        to existingEntries: [AccountVideoEntry]
    ) -> [AccountVideoEntry] {
        var result = existingEntries
        var seen = Set(existingEntries.map(\.id))
        for entry in newEntries where seen.insert(entry.id).inserted {
            result.append(entry)
        }
        return result
    }
}

enum QRCodeLoginState: Equatable {
    case idle
    case loading
    case waiting(QRCodeLoginInfo, String)
    case scanned(QRCodeLoginInfo, String)
    case expired(String)
    case succeeded(String)
    case failed(String)

    var codeInfo: QRCodeLoginInfo? {
        switch self {
        case .waiting(let info, _), .scanned(let info, _):
            return info
        default:
            return nil
        }
    }

    var message: String {
        switch self {
        case .idle:
            return ""
        case .loading:
            return "正在生成二维码"
        case .waiting(_, let message), .scanned(_, let message), .expired(let message), .succeeded(let message), .failed(let message):
            return message
        }
    }
}
