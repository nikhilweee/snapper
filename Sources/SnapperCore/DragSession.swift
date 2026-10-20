import Foundation
import CoreGraphics

public struct DragSession: Sendable {
    public let initialFrame: CGRect
    public private(set) var isMoving = false
    public private(set) var isCancelled = false
    public private(set) var isResize = false

    public init(initialFrame: CGRect) { self.initialFrame = initialFrame }

    public mutating func sample(frame: CGRect) {
        guard !isCancelled else { return }
        if abs(frame.width - initialFrame.width) > 2 || abs(frame.height - initialFrame.height) > 2 {
            isResize = true
        }
        if abs(frame.minX - initialFrame.minX) > 2 || abs(frame.minY - initialFrame.minY) > 2 {
            isMoving = true
        }
    }

    public mutating func cancel() { isCancelled = true }

    public func canPreview(shift: Bool) -> Bool {
        shift && isMoving && !isResize && !isCancelled
    }

    public func canCommit(shift: Bool, pointerInsideZone: Bool) -> Bool {
        canPreview(shift: shift) && pointerInsideZone
    }
}

/// Shared by the UI and Accessibility queue to invalidate late work safely.
public final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    public init() {}
    public var isCancelled: Bool { lock.withLock { cancelled } }
    public func cancel() { lock.withLock { cancelled = true } }
}
