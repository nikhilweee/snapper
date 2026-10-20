import Foundation
import CoreGraphics

public enum Geometry {
    /// AppKit uses a global bottom-left origin; JSON uses the usable frame's top-left.
    public static func rectangle(for zone: Zone, in usableFrame: CGRect) -> CGRect {
        let left = usableFrame.minX + usableFrame.width * zone.x / 100
        let right = usableFrame.minX + usableFrame.width * (zone.x + zone.width) / 100
        let top = usableFrame.maxY - usableFrame.height * zone.y / 100
        let bottom = usableFrame.maxY - usableFrame.height * (zone.y + zone.height) / 100
        // Round edges rather than widths so adjacent zones share the same boundary.
        return CGRect(x: left.rounded(), y: bottom.rounded(),
                      width: right.rounded() - left.rounded(), height: top.rounded() - bottom.rounded())
    }

    /// Half-open edges make shared boundaries deterministic (left/bottom included).
    public static func contains(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y < rect.maxY
    }

    public static func selectedZone(at point: CGPoint, layout: Layout, usableFrame: CGRect) -> Zone? {
        layout.zones.first { contains(point, in: rectangle(for: $0, in: usableFrame)) }
    }

    /// Quartz/AX is top-left relative to the primary display. Works with negative origins.
    public static func accessibilityRect(from appKitRect: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: appKitRect.minX, y: primaryTop - appKitRect.maxY,
               width: appKitRect.width, height: appKitRect.height)
    }

    public static func accessibilityPoint(from point: CGPoint, primaryTop: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryTop - point.y)
    }

    public static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance &&
        abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }
}
