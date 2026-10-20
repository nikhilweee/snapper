import AppKit
import Testing
@testable import Snapper

@MainActor
struct OverlayTests {
    @Test func longLabelStaysInsideZoneAndIsReusedDuringSelection() throws {
        let view = ZoneView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let rectangle = CGRect(x: 100, y: 50, width: 120, height: 200)
        let zone = ZoneView.RenderedZone(id: "editor", name: String(repeating: "Editor ", count: 20), rectangle: rectangle)
        view.update(zones: [zone], selected: nil)
        let label = try #require(view.subviews.first)
        #expect(rectangle.insetBy(dx: 12, dy: 12).contains(label.frame))
        #expect(label.frame.midX == rectangle.midX)
        #expect(label.frame.midY == rectangle.midY)

        view.update(zones: [zone], selected: zone.id)
        #expect(view.subviews.count == 1)
        #expect(view.subviews.first === label)
    }

    @Test func changingLayoutRemovesOldLabelsAndTinyZonesStayUncluttered() throws {
        let view = ZoneView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let zone = ZoneView.RenderedZone(id: "editor", name: "Editor", rectangle: view.bounds)
        view.update(zones: [zone], selected: zone.id)
        let previous = try #require(view.subviews.first)
        let tiny = ZoneView.RenderedZone(id: "tiny", name: "Tiny", rectangle: CGRect(x: 0, y: 0, width: 20, height: 20))
        view.update(zones: [tiny], selected: nil)
        #expect(previous.superview == nil)
        #expect(view.subviews.isEmpty)

        view.update(zones: [zone], selected: nil)
        #expect(view.subviews.count == 1)
        #expect(view.subviews.first !== previous)
    }
}
