import AppKit
import ColorSync
import SnapperCore

struct Display {
    let id: CGDirectDisplayID
    let uuid: String?
    let name: String
    let screen: NSScreen
    let identityIssue: String?

    var frame: CGRect { screen.frame }
    var usableFrame: CGRect { screen.visibleFrame }
}

@MainActor
final class Displays {
    private(set) var connected: [Display] = []
    var primaryTop: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    func refresh() {
        let candidates: [(NSScreen, CGDirectDisplayID, String?)] = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = number.uint32Value
            // A mirrored follower shares its master's logical desktop.
            guard CGDisplayMirrorsDisplay(id) == kCGNullDirectDisplay else { return nil }
            let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
            return (screen, id, uuid)
        }
        let counts = Dictionary(candidates.compactMap { $0.2 }.map { ($0, 1) }, uniquingKeysWith: +)
        connected = candidates.map { screen, id, candidateUUID in
            let unique = candidateUUID.map { counts[$0] == 1 } ?? false
            return Display(id: id, uuid: unique ? candidateUUID : nil, name: screen.localizedName,
                           screen: screen, identityIssue: unique ? nil : "Display identity unavailable or duplicated; selection cannot be saved.")
        }
    }

    func display(at point: CGPoint) -> Display? {
        connected.first { Geometry.contains(point, in: $0.frame) }
    }
}
