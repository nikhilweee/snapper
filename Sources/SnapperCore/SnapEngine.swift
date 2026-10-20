import Foundation
import CoreGraphics

public protocol WindowAdapter {
    func isEligible() throws -> Bool
    func frame() throws -> CGRect
    func setFrame(_ frame: CGRect) throws
}

public enum SnapResult: Equatable {
    case snapped
    case constrained(actual: CGRect)
    case skipped
}

public enum SnapEngine {
    public static func snap(window: WindowAdapter, to target: CGRect,
                            cancelled: () -> Bool = { false }) throws -> SnapResult {
        guard !cancelled(), try window.isEligible() else { return .skipped }
        var actual = try window.frame()
        if Geometry.approximatelyEqual(actual, target) { return .snapped }
        for _ in 0..<2 {
            guard !cancelled() else { return .skipped }
            try window.setFrame(target)
            actual = try window.frame()
            if Geometry.approximatelyEqual(actual, target) { return .snapped }
        }
        return .constrained(actual: actual)
    }
}
