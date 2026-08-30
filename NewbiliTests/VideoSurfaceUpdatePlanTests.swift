import XCTest
@testable import bili

final class VideoSurfaceUpdatePlanTests: XCTestCase {
    private let baseline = VideoSurfaceRepresentableConfiguration(
        prefersNativePlaybackControls: false,
        isPictureInPictureEnabled: true,
        disablesImplicitLayoutAnimations: false,
        usesLiveSurfaceDuringLayoutTransition: false,
        isLayoutTransitioningForSurfaceHandoff: false
    )

    func testUnchangedBoundSurfaceDoesNoHeavyWork() {
        let plan = VideoSurfaceUpdatePlan.resolve(
            previous: baseline,
            next: baseline,
            isBoundToCurrentViewModel: true,
            isPreparingForSurfaceDetach: false
        )

        XCTAssertEqual(
            plan,
            VideoSurfaceUpdatePlan(
                needsSurfaceBinding: false,
                needsPictureInPictureUpdate: false,
                needsLayoutRefresh: false
            )
        )
    }

    func testPictureInPictureChangeDoesNotRebindSurface() {
        let next = VideoSurfaceRepresentableConfiguration(
            prefersNativePlaybackControls: false,
            isPictureInPictureEnabled: false,
            disablesImplicitLayoutAnimations: false,
            usesLiveSurfaceDuringLayoutTransition: false,
            isLayoutTransitioningForSurfaceHandoff: false
        )

        let plan = VideoSurfaceUpdatePlan.resolve(
            previous: baseline,
            next: next,
            isBoundToCurrentViewModel: true,
            isPreparingForSurfaceDetach: false
        )

        XCTAssertFalse(plan.needsSurfaceBinding)
        XCTAssertTrue(plan.needsPictureInPictureUpdate)
        XCTAssertFalse(plan.needsLayoutRefresh)
    }

    func testNativeControlPreferenceRebindsAndRefreshesLayout() {
        let next = VideoSurfaceRepresentableConfiguration(
            prefersNativePlaybackControls: true,
            isPictureInPictureEnabled: true,
            disablesImplicitLayoutAnimations: false,
            usesLiveSurfaceDuringLayoutTransition: false,
            isLayoutTransitioningForSurfaceHandoff: false
        )

        let plan = VideoSurfaceUpdatePlan.resolve(
            previous: baseline,
            next: next,
            isBoundToCurrentViewModel: true,
            isPreparingForSurfaceDetach: false
        )

        XCTAssertTrue(plan.needsSurfaceBinding)
        XCTAssertTrue(plan.needsPictureInPictureUpdate)
        XCTAssertTrue(plan.needsLayoutRefresh)
    }

    func testLayoutTransitionOnlyRefreshesLayout() {
        let next = VideoSurfaceRepresentableConfiguration(
            prefersNativePlaybackControls: false,
            isPictureInPictureEnabled: true,
            disablesImplicitLayoutAnimations: true,
            usesLiveSurfaceDuringLayoutTransition: true,
            isLayoutTransitioningForSurfaceHandoff: true
        )

        let plan = VideoSurfaceUpdatePlan.resolve(
            previous: baseline,
            next: next,
            isBoundToCurrentViewModel: true,
            isPreparingForSurfaceDetach: false
        )

        XCTAssertFalse(plan.needsSurfaceBinding)
        XCTAssertFalse(plan.needsPictureInPictureUpdate)
        XCTAssertTrue(plan.needsLayoutRefresh)
    }
}
