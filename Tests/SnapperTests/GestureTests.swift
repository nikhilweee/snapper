import Foundation
import Testing
@testable import Snapper

@MainActor
struct GestureTests {
    @Test func releaseStopsPollingWithoutCancellingPendingSnap() throws {
        let gesture = DragTracker.Gesture()
        defer { gesture.cancel() }
        var polls = 0
        gesture.drag { polls += 1 }
        let timer = try #require(gesture.timer)
        timer.fire()
        #expect(polls == 1)

        #expect(gesture.finish())
        #expect(gesture.phase == .finishing)
        #expect(!gesture.isTracking)
        #expect(!timer.isValid)
        #expect(gesture.timer == nil)
        #expect(!gesture.token.isCancelled)
        timer.fire()
        gesture.drag { polls += 1 }
        #expect(polls == 1)
        #expect(gesture.timer == nil)
    }

    @Test func cancellationCannotBeReactivatedByLateWork() throws {
        let gesture = DragTracker.Gesture()
        var polls = 0
        gesture.drag { polls += 1 }
        let timer = try #require(gesture.timer)
        gesture.cancel()

        timer.fire()
        gesture.drag { polls += 1 }
        #expect(!gesture.finish())
        #expect(gesture.phase == .cancelled)
        #expect(gesture.token.isCancelled)
        #expect(!gesture.isTracking)
        #expect(!timer.isValid)
        #expect(gesture.timer == nil)
        #expect(polls == 0)
    }

    @Test func replacingGestureKeepsCancellationAndCallbacksSeparate() throws {
        let previous = DragTracker.Gesture()
        var previousPolls = 0
        previous.drag { previousPolls += 1 }
        let oldTimer = try #require(previous.timer)
        previous.cancel()

        let current = DragTracker.Gesture()
        defer { current.cancel() }
        var currentPolls = 0
        current.drag { currentPolls += 1 }
        oldTimer.fire()
        current.timer?.fire()
        #expect(previousPolls == 0)
        #expect(currentPolls == 1)
        #expect(previous.token.isCancelled)
        #expect(!current.token.isCancelled)
        #expect(current.phase == .dragging)
    }

    @Test func clickWithoutDraggingDoesNotStartPolling() {
        let gesture = DragTracker.Gesture()
        #expect(gesture.isTracking)
        #expect(gesture.timer == nil)
        #expect(!gesture.finish())
        gesture.cancel()
        #expect(gesture.token.isCancelled)
    }
}
