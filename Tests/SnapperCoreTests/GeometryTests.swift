import Foundation
import Testing
import CoreGraphics
import SnapperCore

struct GeometryTests {
    @Test func testPercentagesUseUsableTopLeft() throws {
        let zone = Zone(id: "top-left", name: "Top Left", x: 0, y: 0, width: 50, height: 50)
        let usable = CGRect(x: 0, y: 80, width: 1440, height: 796)
        #expect(Geometry.rectangle(for: zone, in: usable) == CGRect(x: 0, y: 478, width: 720, height: 398))
    }

    @Test func testNegativeOriginsAndVerticalArrangement() throws {
        let zone = Zone(id: "right", name: "Right", x: 50, y: 0, width: 50, height: 100)
        let usable = CGRect(x: -1920, y: -1000, width: 1920, height: 1000)
        let appKit = Geometry.rectangle(for: zone, in: usable)
        #expect(appKit == CGRect(x: -960, y: -1000, width: 960, height: 1000))
        #expect(Geometry.accessibilityRect(from: appKit, primaryTop: 900) == CGRect(x: -960, y: 900, width: 960, height: 1000))
        #expect(Geometry.accessibilityPoint(from: CGPoint(x: -500, y: 1200), primaryTop: 900) == CGPoint(x: -500, y: -300))
    }

    @Test func testSharedEdgesAndOutsideDesktop() throws {
        let layout = Configuration.starter.layouts[0]
        let usable = CGRect(x: 0, y: 0, width: 1000, height: 800)
        #expect(Geometry.selectedZone(at: CGPoint(x: 499, y: 400), layout: layout, usableFrame: usable)?.id == "left")
        #expect(Geometry.selectedZone(at: CGPoint(x: 500, y: 400), layout: layout, usableFrame: usable)?.id == "right")
        #expect(Geometry.selectedZone(at: CGPoint(x: 1000, y: 400), layout: layout, usableFrame: usable) == nil)
        #expect(Geometry.selectedZone(at: CGPoint(x: 10, y: 801), layout: layout, usableFrame: usable) == nil)
    }

    @Test func testOverlappingZonesRespectConfigurationOrder() throws {
        let layout = Layout(id: "overlap", name: "Overlap", zones: [
            Zone(id: "first", name: "First", x: 0, y: 0, width: 100, height: 100),
            Zone(id: "second", name: "Second", x: 0, y: 0, width: 50, height: 100)
        ])
        #expect(Geometry.selectedZone(at: CGPoint(x: 10, y: 10), layout: layout, usableFrame: CGRect(x: 0, y: 0, width: 100, height: 100))?.id == "first")
    }

    @Test func testRoundedEdgesStayAdjacentInLogicalPoints() throws {
        let layout = Configuration.starter.layouts[1]
        let usable = CGRect(x: -1512, y: 30, width: 1511, height: 945)
        let rectangles = layout.zones.map { Geometry.rectangle(for: $0, in: usable) }
        #expect(rectangles[0].maxX == rectangles[1].minX)
        #expect(rectangles[1].maxX == rectangles[2].minX)
        #expect(rectangles[0].minX == usable.minX)
        #expect(rectangles[2].maxX == usable.maxX)
        // Backing scale is intentionally irrelevant to percentage/AX geometry.
        #expect(rectangles.reduce(0) { $0 + $1.width } == usable.width)
    }
}
