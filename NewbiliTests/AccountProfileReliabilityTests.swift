import Foundation
import Testing
@testable import bili

@MainActor
struct AccountProfileReliabilityTests {
    @Test
    func `level and experience survive a session store restart`() throws {
        let keychain = makeKeychain()
        let store = SessionStore(keychain: keychain)
        defer { try? store.logout() }
        try saveMainAccount(mid: 1001, session: "main-session", in: store)
        store.updateUser(makeUser(mid: 1001, name: "主账号", level: 5, current: 19_800, next: 28_800))

        let reloaded = SessionStore(keychain: keychain)
        let display = MineAccountProfileDisplayModel(
            user: reloaded.user,
            fallbackAccount: reloaded.mainAccount
        )

        #expect(reloaded.user?.currentLevel == 5)
        #expect(reloaded.user?.levelInfo?.currentExperience == 19_800)
        #expect(display.username == "主账号")
        #expect(display.uidText == "UID 1001")
        #expect(display.experienceText == "经验 19800/28800")
        #expect(display.experienceProgress == 0.5)
    }

    @Test
    func `profiles remain isolated while switching main accounts`() throws {
        let keychain = makeKeychain()
        let store = SessionStore(keychain: keychain)
        defer { try? store.logout() }
        try saveMainAccount(mid: 1001, session: "main-session", in: store)
        store.updateUser(makeUser(mid: 1001, name: "主账号", level: 4, current: 12_000, next: 18_000))
        _ = try store.saveAdditionalAccount(
            cookies(mid: 2002, session: "second-session"),
            credentialKind: .web
        )
        store.updateAccountUser(
            mid: 2002,
            user: makeUser(mid: 2002, name: "副账号", level: 6, current: 40_000, next: nil)
        )

        try store.selectMainAccount(mid: 2002)
        #expect(store.user?.uname == "副账号")
        #expect(store.user?.currentLevel == 6)
        #expect(store.user?.levelInfo?.progress == 1)

        try store.selectMainAccount(mid: 1001)
        #expect(store.user?.uname == "主账号")
        #expect(store.user?.currentLevel == 4)

        let reloaded = SessionStore(keychain: keychain)
        try reloaded.selectMainAccount(mid: 2002)
        #expect(reloaded.user?.uname == "副账号")
        #expect(reloaded.user?.currentLevel == 6)
        #expect(reloaded.user?.levelInfo?.effectiveNextLevelExperience == 40_000)
    }

    @Test
    func `transient refresh failure keeps the last successful profile`() async throws {
        let keychain = makeKeychain()
        let store = SessionStore(keychain: keychain)
        defer { try? store.logout() }
        try saveMainAccount(mid: 1001, session: "main-session", in: store)
        store.updateUser(makeUser(mid: 1001, name: "缓存账号", level: 5, current: 20_000, next: 28_800))

        let defaultsName = "cc.bili.tests.account-profile.defaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let libraryStore = LibraryStore(userDefaults: defaults)
        let api = BiliAPIClient(
            session: .shared,
            sessionStore: store,
            libraryStore: libraryStore,
            homeRecommendDiagnosticsStore: .shared
        )
        let viewModel = MineViewModel(
            api: api,
            sessionStore: store,
            navUserLoader: { throw URLError(.timedOut) }
        )

        await viewModel.refreshUser()

        #expect(store.isLoggedIn)
        #expect(store.user?.uname == "缓存账号")
        #expect(store.user?.currentLevel == 5)
        if case .failed = viewModel.state {
            // Expected: the retry row is driven by this state.
        } else {
            Issue.record("A transient profile failure should expose a retry state")
        }
    }

    @Test
    func `logout clears persisted profile and level`() throws {
        let keychain = makeKeychain()
        let store = SessionStore(keychain: keychain)
        try saveMainAccount(mid: 1001, session: "main-session", in: store)
        store.updateUser(makeUser(mid: 1001, name: "待退出账号", level: 3, current: 6_000, next: 10_800))

        try store.logout()
        let reloaded = SessionStore(keychain: keychain)

        #expect(!reloaded.isLoggedIn)
        #expect(reloaded.accounts.isEmpty)
        #expect(reloaded.user == nil)
    }

    @Test
    func `level six display uses a finite completed boundary`() {
        let user = makeUser(mid: 1001, name: "满级账号", level: 6, current: 40_000, next: nil)
        let display = MineAccountProfileDisplayModel(user: user, fallbackAccount: nil)

        #expect(display.level == 6)
        #expect(display.experienceText == "经验 40000/40000")
        #expect(display.experienceProgress == 1)
        #expect(display.experienceProgress?.isFinite == true)
    }

    private func makeKeychain() -> KeychainStore {
        KeychainStore(service: "cc.bili.tests.account-profile.\(UUID().uuidString)")
    }

    private func saveMainAccount(mid: Int, session: String, in store: SessionStore) throws {
        try store.saveLoginCookies(
            [
                "buvid3": "buvid-\(mid)",
                "DedeUserID": String(mid),
                "SESSDATA": session,
                "bili_jct": "csrf-\(mid)"
            ],
            credentialKind: .web
        )
    }

    private func cookies(mid: Int, session: String) -> [HTTPCookie] {
        [
            cookie(name: "buvid3", value: "buvid-\(mid)"),
            cookie(name: "DedeUserID", value: String(mid)),
            cookie(name: "SESSDATA", value: session),
            cookie(name: "bili_jct", value: "csrf-\(mid)")
        ]
    }

    private func cookie(name: String, value: String) -> HTTPCookie {
        HTTPCookie(
            properties: [
                .domain: ".bilibili.com",
                .path: "/",
                .name: name,
                .value: value,
                .secure: "TRUE"
            ]
        )!
    }

    private func makeUser(
        mid: Int,
        name: String,
        level: Int,
        current: Int,
        next: Int?
    ) -> NavUserInfo {
        NavUserInfo(
            isLogin: true,
            face: "https://example.com/\(mid).jpg",
            uname: name,
            mid: mid,
            wbiImg: nil,
            levelInfo: NavLevelInfo(
                currentLevel: level,
                currentMinimumExperience: level == 6 ? current : 10_800,
                currentExperience: current,
                nextLevelExperience: next
            )
        )
    }
}
