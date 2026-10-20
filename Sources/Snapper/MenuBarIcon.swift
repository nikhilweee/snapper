import AppKit

@MainActor
enum MenuBarIcon {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            // The app icon's tall left zone and two stacked right zones.
            NSColor.black.setFill()
            for rectangle in [NSRect(x: 2, y: 2, width: 6, height: 14),
                              NSRect(x: 10, y: 10, width: 6, height: 6),
                              NSRect(x: 10, y: 2, width: 6, height: 6)] {
                NSBezierPath(roundedRect: rectangle, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Snapper"
        return image
    }
}
