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
    @Published private(set) var watchLaterLoadMoreState: LoadingState = .idle {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published private(set) var watchLaterMutationState: LoadingState = .idle
    @Published private(set) var watchLaterHasMore = false {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published private(set) var watchLaterTotalCount = 0 {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published var watchLaterEntries: [AccountVideoEntry] = [] {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published private(set) var historyLoadMoreState: LoadingState = .idle {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published private(set) var historyHasMore = false {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published var accountHistory: [AccountVideoEntry] = [] {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published var accountFavorites: [AccountVideoEntry] = [] {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published var favoriteFolders: [FavoriteFolder] = [] {
        didSet { accountLibraryRevision &+= 1 }
    }
    @Published var favoriteFolderEntries: [Int: [AccountVideoEntry]] = [:] {
        didSet { favoriteFolderRevision &+= 1 }
    }
    @Published var favoriteFolderEntryStates: [Int: LoadingState] = [:] {
        didSet { favoriteFolderRevision &+= 1 }
    }
    @Published private(set) var favoriteFolderLoadMoreStates: [Int: LoadingState] = [:] {
        didSet { favoriteFolderRevision &+= 1 }
    }
    @Published private(set) var favoriteFolderHasMore: [Int: Bool] = [:] {
        didSet { favoriteFolderRevision &+= 1 }
    }
    @Published private(set) var accountLibraryRevision = 0
    @Published private(set) var favoriteFolderRevision = 0

    private let api: BiliAPIClient
    private let sessionStore: SessionStore
    private var qrLoginTask: Task<Void, Never>?
    private let accountLibraryPageSize = 20
    private var historyCursor: AccountHistoryCursor?
    private var favoriteFolderPages: [Int: Int] = [:]
    private var watchLaterPage = 1
    private var watchLaterFilter: WatchLaterFilter = .all
    private var watchLaterKeyword = ""
    private var watchLaterSortOrder: WatchLaterSortOrder = .newest
    private var watchLaterRequestGeneration = 0

    init(api: BiliAPIClient, sessionStore: SessionStore) {
        self.api = api
        self.sessionStore = sessionStore
    }

    func refreshUser() async {
        guard sessionStore.isLoggedIn else { return }
        do {
            let user = try await api.fetchNavUser()
            if user.isLogin == true {
                sessionStore.updateUser(user)
                await refreshAccountLibrary()
            } else {
                try? sessionStore.logout()
                loginMessage = "登录已失效，请重新登录"
            }
        } catch {
            sessionStore.updateUser(nil)
        }
    }

    func refreshAccountLibrary() async {
        guard sessionStore.isLoggedIn else {
            resetAccountLibraryState()
            return
        }

        async let history: Void = refreshHistory()
        async let favorites: Void = refreshFavorites()
        async let watchLater: Void = refreshWatchLater()
        _ = await (history, favorites, watchLater)
    }

    func refreshHistory() async {
        guard sessionStore.isLoggedIn else { return }
        historyState = .loading
        historyLoadMoreState = .idle
        historyCursor = nil
        historyHasMore = false
        do {
            let page = try await api.fetchAccountHistoryPage(pageSize: accountLibraryPageSize)
            accountHistory = Self.uniqued(page.entries)
            historyCursor = page.nextHistoryCursor
            historyHasMore = page.hasMore
            historyState = .loaded
        } catch {
            historyState = .failed(error.localizedDescription)
        }
    }

    func refreshFavorites() async {
        guard sessionStore.isLoggedIn else { return }
        favoriteState = .loading
        do {
            favoriteFolders = try await api.fetchFavoriteFolders()
            accountFavorites = try await api.fetchAccountFavorites()
            favoriteState = .loaded
        } catch {
            favoriteState = .failed(error.localizedDescription)
        }
    }

    func refreshWatchLater(
        filter: WatchLaterFilter? = nil,
        keyword: String? = nil,
        sortOrder: WatchLaterSortOrder? = nil
    ) async {
        guard sessionStore.isLoggedIn else { return }
        if let filter {
            watchLaterFilter = filter
        }
        if let keyword {
            watchLaterKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let sortOrder {
            watchLaterSortOrder = sortOrder
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
                filter: watchLaterFilter,
                keyword: watchLaterKeyword,
                sortOrder: watchLaterSortOrder
            )
            guard generation == watchLaterRequestGeneration else { return }
            watchLaterEntries = Self.uniqued(page.entries)
            watchLaterTotalCount = page.totalCount
            watchLaterHasMore = page.hasMore
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
        watchLaterLoadMoreState = .loading
        do {
            let page = try await api.fetchWatchLaterPage(
                page: nextPage,
                pageSize: accountLibraryPageSize,
                filter: watchLaterFilter,
                keyword: watchLaterKeyword,
                sortOrder: watchLaterSortOrder
            )
            guard generation == watchLaterRequestGeneration else { return }
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

    func refreshFavoriteFolder(_ folder: FavoriteFolder) async {
        guard sessionStore.isLoggedIn else { return }
        favoriteFolderEntryStates[folder.id] = .loading
        favoriteFolderLoadMoreStates[folder.id] = .idle
        favoriteFolderPages[folder.id] = 1
        favoriteFolderHasMore[folder.id] = false
        do {
            let page = try await api.fetchFavoriteFolderVideoPage(
                folderID: folder.id,
                page: 1,
                pageSize: accountLibraryPageSize
            )
            favoriteFolderEntries[folder.id] = Self.uniqued(page.entries)
            favoriteFolderHasMore[folder.id] = page.hasMore
            favoriteFolderEntryStates[folder.id] = .loaded
        } catch {
            favoriteFolderEntryStates[folder.id] = .failed(error.localizedDescription)
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
        historyLoadMoreState = .loading
        do {
            let page = try await api.fetchAccountHistoryPage(
                cursor: historyCursor,
                pageSize: accountLibraryPageSize
            )
            let previousCount = accountHistory.count
            accountHistory = Self.appendingUnique(page.entries, to: accountHistory)
            historyCursor = page.nextHistoryCursor
            historyHasMore = page.hasMore && accountHistory.count > previousCount
            historyLoadMoreState = .idle
        } catch {
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
        let nextPage = (favoriteFolderPages[folder.id] ?? 1) + 1
        favoriteFolderLoadMoreStates[folder.id] = .loading
        do {
            let page = try await api.fetchFavoriteFolderVideoPage(
                folderID: folder.id,
                page: nextPage,
                pageSize: accountLibraryPageSize
            )
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
        try? sessionStore.logout()
        BiliWebCookieStore.clearLoginCookies()
        accountHistory = []
        accountFavorites = []
        watchLaterEntries = []
        favoriteFolders = []
        favoriteFolderEntries = [:]
        favoriteFolderEntryStates = [:]
        historyLoadMoreState = .idle
        historyHasMore = false
        historyCursor = nil
        favoriteFolderLoadMoreStates = [:]
        favoriteFolderHasMore = [:]
        favoriteFolderPages = [:]
        historyState = .idle
        favoriteState = .idle
        watchLaterState = .idle
        watchLaterLoadMoreState = .idle
        watchLaterMutationState = .idle
        watchLaterHasMore = false
        watchLaterTotalCount = 0
        watchLaterPage = 1
        watchLaterRequestGeneration &+= 1
        loginMessage = ""
        qrLoginState = .idle
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
        accountHistory = []
        accountFavorites = []
        watchLaterEntries = []
        favoriteFolders = []
        favoriteFolderEntries = [:]
        favoriteFolderEntryStates = [:]
        historyLoadMoreState = .idle
        historyHasMore = false
        historyCursor = nil
        favoriteFolderLoadMoreStates = [:]
        favoriteFolderHasMore = [:]
        favoriteFolderPages = [:]
        historyState = .idle
        favoriteState = .idle
        watchLaterState = .idle
        watchLaterLoadMoreState = .idle
        watchLaterMutationState = .idle
        watchLaterHasMore = false
        watchLaterTotalCount = 0
        watchLaterPage = 1
        watchLaterRequestGeneration &+= 1
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
