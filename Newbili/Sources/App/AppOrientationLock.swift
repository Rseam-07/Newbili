import UIKit
import UserNotifications

nonisolated enum AppOrientationPolicy {
    static func rootOrientations(for idiom: UIUserInterfaceIdiom) -> UIInterfaceOrientationMask {
        idiom == .pad ? .all : .allButUpsideDown
    }
}

@MainActor
enum AppOrientationLock {
    private(set) static var supportedOrientations: UIInterfaceOrientationMask = rootOrientations

    static var rootOrientations: UIInterfaceOrientationMask {
        AppOrientationPolicy.rootOrientations(for: UIDevice.current.userInterfaceIdiom)
    }

    static func update(
        to orientations: UIInterfaceOrientationMask,
        in scene: UIWindowScene?,
        requestsGeometryUpdate: Bool = false
    ) {
        supportedOrientations = orientations

        let targetScenes = scenes(matching: scene)
        requestInterfaceUpdates(in: targetScenes)

        guard requestsGeometryUpdate else { return }
        requestGeometryUpdate(to: orientations, in: targetScenes)
    }

    static func restorePortrait(in scene: UIWindowScene? = nil) {
        update(to: .portrait, in: scene, requestsGeometryUpdate: true)
    }

    static func restoreRootOrientations(in scene: UIWindowScene? = nil) {
        update(to: rootOrientations, in: scene, requestsGeometryUpdate: true)
    }

    static func requestGeometryUpdate(
        to orientations: UIInterfaceOrientationMask,
        in scene: UIWindowScene?
    ) {
        requestGeometryUpdate(to: orientations, in: scenes(matching: scene))
    }

    private static func scenes(matching scene: UIWindowScene?) -> [UIWindowScene] {
        if let scene {
            return [scene]
        }
        return UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    }

    private static func requestInterfaceUpdates(in scenes: [UIWindowScene]) {
        scenes
            .flatMap(\.windows)
            .filter(\.participatesInAppOrientationChrome)
            .compactMap(\.rootViewController)
            .forEach { controller in
                controller.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller.setNeedsStatusBarAppearanceUpdate()
                controller.setNeedsUpdateOfHomeIndicatorAutoHidden()
            }
    }

    private static func requestGeometryUpdate(
        to orientations: UIInterfaceOrientationMask,
        in scenes: [UIWindowScene]
    ) {
        scenes.forEach { scene in
            scene.requestGeometryUpdate(
                UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientations)
            ) { _ in }
        }
    }
}

private extension UIWindow {
    var participatesInAppOrientationChrome: Bool {
        !isHidden
            && alpha > 0
            && !(self is PlayerHostWindow)
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UIWindow.appearance().backgroundColor = LaunchAppearance.backgroundColor
        return true
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PlayerSystemMediaControls.clear()
        LaunchAppearance.applyToConnectedWindows()
        UNUserNotificationCenter.current().delegate = self
        UpdateNotificationBackgroundRefreshCoordinator.register()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let bvid = response.notification.request.content.userInfo["bvid"] as? String,
              let normalizedBVID = AppIntentVideoIdentifier.normalizedBVID(from: bvid)
        else { return }
        AppIntentRouteInbox.shared.enqueue(.video(bvid: normalizedBVID))
    }

    func applicationWillTerminate(_ application: UIApplication) {
        ActivePlaybackCoordinator.shared.stopActivePlayback()
        PlayerSystemMediaControls.clear()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        ActivePlaybackCoordinator.shared.pauseActivePlaybackForAppBackground()
    }

    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) {
        ActivePlaybackCoordinator.shared.pauseActivePlaybackForAppBackground()
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return AppOrientationLock.supportedOrientations
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        RemoteImageDisplayMemoryCache.shared.clear()
        Task {
            await RemoteImageCache.shared.clearMemoryCache(cancelInFlight: true)
            await PlayURLCache.shared.clearMemoryCache()
            await SubtitleDanmakuResourceCache.shared.clear()
        }
    }
}

@MainActor
enum LaunchAppearance {
    static let backgroundColor = UIColor(named: "NewbiliDynamicLaunchBackground") ?? UIColor { traitCollection in
        UIColor.systemBackground.resolvedColor(with: traitCollection)
    }

    static func apply(to window: UIWindow?) {
        guard let window else { return }
        window.backgroundColor = backgroundColor
    }

    static func applyToConnectedWindows() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach(apply(to:))
    }
}
