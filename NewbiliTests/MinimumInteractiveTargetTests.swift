import CoreGraphics
import Testing
@testable import bili

struct MinimumInteractiveTargetTests {
    @Test
    func `iOS interactive target policy remains at least 44 points`() {
        #expect(BiliInteractiveTarget.minimumSide == 44)
        #expect(BiliInteractiveTarget.minimumSide >= 44)
    }
}
