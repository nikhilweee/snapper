import AppKit
import SnapperCore

@MainActor
final class OverlayController {
    private var panel: NSPanel?
    private var displayID: CGDirectDisplayID?

    func show(layout: Layout, on display: Display, pointer: CGPoint) {
        if panel == nil || displayID != display.id {
            hide()
            let panel = NSPanel(contentRect: display.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.contentView = ZoneView()
            self.panel = panel
            displayID = display.id
        }
        guard let panel, let view = panel.contentView as? ZoneView else { return }
        if panel.frame != display.frame { panel.setFrame(display.frame, display: false) }
        let selected = Geometry.selectedZone(at: pointer, layout: layout, usableFrame: display.usableFrame)?.id
        let zones = layout.zones.map { zone in
            let global = Geometry.rectangle(for: zone, in: display.usableFrame)
            return ZoneView.RenderedZone(id: zone.id, name: zone.name,
                                         rectangle: global.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY))
        }
        view.update(zones: zones, selected: selected)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        displayID = nil
    }
}

@MainActor
final class ZoneView: NSView {
    struct RenderedZone: Equatable {
        let id: String
        let name: String
        let rectangle: CGRect
    }

    private var zones: [RenderedZone] = []
    private var selected: String?

    func update(zones: [RenderedZone], selected: String?) {
        guard self.zones != zones || self.selected != selected else { return }
        if self.zones != zones {
            subviews.forEach { $0.removeFromSuperview() }
            for zone in zones {
                if let label = makeLabel(for: zone) { addSubview(label) }
            }
        }
        self.zones = zones
        self.selected = selected
        needsDisplay = true
    }

    private func makeLabel(for zone: RenderedZone) -> NSView? {
        let text = NSTextField(labelWithString: zone.name)
        text.font = .systemFont(ofSize: 13, weight: .semibold)
        text.textColor = .labelColor
        text.alignment = .center
        text.lineBreakMode = .byTruncatingTail
        text.maximumNumberOfLines = 1

        let available = zone.rectangle.insetBy(dx: 12, dy: 12)
        let height = ceil(text.fittingSize.height) + 16
        guard available.width >= 40, available.height >= height else { return nil }
        let size = NSSize(width: min(ceil(text.fittingSize.width) + 28, available.width), height: height)
        let frame = NSRect(x: zone.rectangle.midX - size.width / 2,
                           y: zone.rectangle.midY - size.height / 2, width: size.width, height: size.height)
        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.autoresizingMask = [.width, .height]
        text.frame = content.bounds.insetBy(dx: 14, dy: 8)
        text.autoresizingMask = [.width, .height]
        content.addSubview(text)

        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: frame)
            glass.style = .regular
            glass.cornerRadius = height / 2
            glass.contentView = content
            return glass
        }
        #endif

        let material = NSVisualEffectView(frame: frame)
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = height / 2
        material.layer?.masksToBounds = true
        material.addSubview(content)
        return material
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill(using: .copy)
        for zone in zones {
            let rectangle = zone.rectangle
            guard rectangle.width > 0, rectangle.height > 0 else { continue }
            let active = zone.id == selected
            let path = NSBezierPath(roundedRect: rectangle.insetBy(dx: min(3, rectangle.width / 4), dy: min(3, rectangle.height / 4)), xRadius: 10, yRadius: 10)
            NSColor.controlAccentColor.withAlphaComponent(active ? 0.20 : 0.06).setFill()
            path.fill()
            NSColor.controlAccentColor.withAlphaComponent(active ? 0.95 : 0.45).setStroke()
            path.lineWidth = active ? 3 : 1.5
            path.stroke()
        }
    }
}
