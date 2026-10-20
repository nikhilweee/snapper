import Foundation
import Testing
import CoreGraphics
import SnapperCore

struct DragAndSnapTests {
    let initial = CGRect(x: 100, y: 100, width: 700, height: 500)
    let moved = CGRect(x: 200, y: 150, width: 700, height: 500)

    @Test func testShiftBeforeAndDuringDrag() throws {
        var drag = DragSession(initialFrame: initial)
        #expect(!(drag.canPreview(shift: true)))
        drag.sample(frame: moved)
        #expect(drag.canPreview(shift: true))
        #expect(!(drag.canPreview(shift: false)))
        #expect(drag.canCommit(shift: true, pointerInsideZone: true))
        #expect(!(drag.canCommit(shift: false, pointerInsideZone: true)))
        #expect(!(drag.canCommit(shift: true, pointerInsideZone: false)))
    }

    @Test func testContentDraggingAndJitterDoNotTrigger() throws {
        var drag = DragSession(initialFrame: initial)
        drag.sample(frame: initial)
        drag.sample(frame: initial.offsetBy(dx: 1, dy: 1))
        #expect(!(drag.canCommit(shift: true, pointerInsideZone: true)))
    }

    @Test func testResizeIncludingTopLeftResizeNeverTriggers() throws {
        var drag = DragSession(initialFrame: initial)
        drag.sample(frame: CGRect(x: 50, y: 50, width: 750, height: 550))
        #expect(drag.isResize)
        #expect(!(drag.canPreview(shift: true)))
        drag.sample(frame: moved)
        #expect(!(drag.canCommit(shift: true, pointerInsideZone: true)))
    }

    @Test func testCancellationCannotBeReactivatedByLateSample() throws {
        var drag = DragSession(initialFrame: initial)
        drag.sample(frame: moved)
        drag.cancel()
        drag.sample(frame: moved)
        #expect(!(drag.canCommit(shift: true, pointerInsideZone: true)))
        let token = CancellationToken()
        #expect(!(token.isCancelled))
        token.cancel()
        #expect(token.isCancelled)
    }

    @Test func testSnapSuccessAndCorrectiveAttempt() throws {
        let window = MockWindow(initial)
        #expect(try SnapEngine.snap(window: window, to: moved) == .snapped)
        #expect(window.writes == 1)
        let delayed = MockWindow(initial)
        delayed.ignoreFirstWrite = true
        #expect(try SnapEngine.snap(window: delayed, to: moved) == .snapped)
        #expect(delayed.writes == 2)
    }

    @Test func testWindowAlreadyInZoneIsNotRepositioned() throws {
        let window = MockWindow(moved)
        #expect(try SnapEngine.snap(window: window, to: moved) == .snapped)
        #expect(window.writes == 0)
    }

    @Test func testMinimumSizeConstraintStopsAfterTwoWrites() throws {
        let window = MockWindow(initial)
        window.constrained = true
        #expect(try SnapEngine.snap(window: window, to: moved) == .constrained(actual: initial))
        #expect(window.writes == 2)
    }

    @Test func testIneligibleAndCancelledWindowsNeverWrite() throws {
        let window = MockWindow(initial)
        window.eligible = false
        #expect(try SnapEngine.snap(window: window, to: moved) == .skipped)
        #expect(window.writes == 0)
        window.eligible = true
        #expect(try SnapEngine.snap(window: window, to: moved, cancelled: { true }) == .skipped)
        #expect(window.writes == 0)
    }

    @Test func testFailurePropagatesWithoutRetryLoop() throws {
        let window = MockWindow(initial)
        window.fail = true
        #expect(throws: (any Error).self) { try SnapEngine.snap(window: window, to: moved) }
        #expect(window.writes == 1)
    }

    @Test func testCancellationBetweenAttemptsStopsCorrection() throws {
        let window = MockWindow(initial)
        window.constrained = true
        #expect(try SnapEngine.snap(window: window, to: moved, cancelled: { window.writes > 0 }) == .skipped)
        #expect(window.writes == 1)
    }
}

private final class MockWindow: WindowAdapter {
    var current: CGRect
    var eligible = true
    var constrained = false
    var ignoreFirstWrite = false
    var fail = false
    var writes = 0
    init(_ frame: CGRect) { current = frame }
    func isEligible() throws -> Bool { eligible }
    func frame() throws -> CGRect { current }
    func setFrame(_ frame: CGRect) throws {
        writes += 1
        if fail { throw ConfigError.invalid("Mock AX failure") }
        if !constrained && !(ignoreFirstWrite && writes == 1) { current = frame }
    }
}
