import UIKit
import XCTest
@testable import bili

final class SystemBackGestureDelegateLeaseTests: XCTestCase {
    @MainActor
    func testReleaseRestoresInheritedEdgePopDelegate() throws {
        let navigationController = makeNavigationController()
        let edgePopGesture = try XCTUnwrap(navigationController.interactivePopGestureRecognizer)
        let inheritedDelegate = GestureDelegate()
        let owner = GestureDelegate()
        let lease = SystemBackGestureDelegateLease()
        edgePopGesture.delegate = inheritedDelegate

        lease.acquire(in: navigationController, owner: owner)
        XCTAssertTrue(edgePopGesture.delegate === owner)

        lease.release()
        XCTAssertTrue(edgePopGesture.delegate === inheritedDelegate)
    }

    @MainActor
    func testReleaseDoesNotOverwriteANewerGestureOwner() throws {
        let navigationController = makeNavigationController()
        let edgePopGesture = try XCTUnwrap(navigationController.interactivePopGestureRecognizer)
        let inheritedDelegate = GestureDelegate()
        let owner = GestureDelegate()
        let newerOwner = GestureDelegate()
        let lease = SystemBackGestureDelegateLease()
        edgePopGesture.delegate = inheritedDelegate

        lease.acquire(in: navigationController, owner: owner)
        edgePopGesture.delegate = newerOwner
        lease.release()

        XCTAssertTrue(edgePopGesture.delegate === newerOwner)
    }

    @MainActor
    private func makeNavigationController() -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        navigationController.pushViewController(UIViewController(), animated: false)
        navigationController.loadViewIfNeeded()
        return navigationController
    }
}

private final class GestureDelegate: NSObject, UIGestureRecognizerDelegate {}
