import AppKit
import ApplicationServices
import SnapperCore

enum AccessibilityFailure: LocalizedError {
    case api(String, AXError)
    case unsupported

    var errorDescription: String? {
        switch self {
        case .api(let action, let code): return "Could not \(action) (Accessibility error \(code.rawValue))."
        case .unsupported: return "This window does not support moving and resizing."
        }
    }
}

/// All access to the AX element is confined to AccessibilityWorker's serial queue.
final class AccessibleWindow: WindowAdapter, @unchecked Sendable {
    private let element: AXUIElement
    fileprivate var writeToken: CancellationToken?
    init(_ element: AXUIElement) {
        self.element = element
        AXUIElementSetMessagingTimeout(element, 0.15)
    }

    func attribute(_ name: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value
    }

    func isEligible() throws -> Bool {
        guard AXIsProcessTrusted(), attribute(kAXSubroleAttribute as CFString) as? String == (kAXStandardWindowSubrole as String),
              let minimized = attribute(kAXMinimizedAttribute as CFString) as? Bool,
              !minimized else { return false }
        if attribute("AXFullScreen" as CFString) as? Bool == true { return false }
        for attribute in [kAXPositionAttribute, kAXSizeAttribute] {
            var settable = DarwinBoolean(false)
            guard AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success,
                  settable.boolValue else { return false }
        }
        return true
    }

    func frame() throws -> CGRect {
        guard let position = attribute(kAXPositionAttribute as CFString), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(kAXSizeAttribute as CFString), CFGetTypeID(size) == AXValueGetTypeID() else {
            throw AccessibilityFailure.unsupported
        }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions),
              point.x.isFinite, point.y.isFinite, dimensions.width.isFinite, dimensions.height.isFinite,
              dimensions.width > 0, dimensions.height > 0 else { throw AccessibilityFailure.unsupported }
        return CGRect(origin: point, size: dimensions)
    }

    func setFrame(_ frame: CGRect) throws {
        // Position first so the destination display's size constraints apply, then
        // position again because applications can reposition a window while resizing.
        var point = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &point), let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw AccessibilityFailure.unsupported
        }
        for (name, value) in [(kAXPositionAttribute, positionValue), (kAXSizeAttribute, sizeValue), (kAXPositionAttribute, positionValue)] {
            guard writeToken?.isCancelled != true, AXIsProcessTrusted() else { throw CancellationError() }
            let result = AXUIElementSetAttributeValue(element, name as CFString, value)
            guard result == .success else { throw AccessibilityFailure.api("set window bounds", result) }
        }
    }
}

final class AccessibilityWorker {
    private let queue = DispatchQueue(label: "com.nikhilweee.snapper.accessibility", qos: .userInteractive)

    func resolve(at point: CGPoint, token: CancellationToken,
                 completion: @escaping @MainActor (AccessibleWindow?, CGRect?) -> Void) {
        queue.async {
            guard !token.isCancelled, AXIsProcessTrusted() else { return }
            let system = AXUIElementCreateSystemWide()
            AXUIElementSetMessagingTimeout(system, 0.15)
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit) == .success,
                  var current = hit else {
                DispatchQueue.main.async { completion(nil, nil) }
                return
            }
            var resolved: AccessibleWindow?
            for _ in 0..<16 {
                guard !token.isCancelled else { return }
                let candidate = AccessibleWindow(current)
                if candidate.attribute(kAXRoleAttribute as CFString) as? String == (kAXWindowRole as String) {
                    resolved = candidate
                    break
                }
                if let window = candidate.attribute(kAXWindowAttribute as CFString), CFGetTypeID(window) == AXUIElementGetTypeID() {
                    resolved = AccessibleWindow(window as! AXUIElement)
                    break
                }
                guard let parent = candidate.attribute(kAXParentAttribute as CFString), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
                current = parent as! AXUIElement
            }
            guard !token.isCancelled else { return }
            let eligible = resolved.flatMap { (try? $0.isEligible()) == true ? $0 : nil }
            let frame = eligible.flatMap { try? $0.frame() }
            DispatchQueue.main.async { completion(eligible, frame) }
        }
    }

    func inspect(_ window: AccessibleWindow, token: CancellationToken, checkEligibility: Bool = false,
                 completion: @escaping @MainActor (CGRect?) -> Void) {
        queue.async {
            guard !token.isCancelled else { return }
            let allowed = !checkEligibility || (try? window.isEligible()) == true
            let frame = allowed ? try? window.frame() : nil
            DispatchQueue.main.async { completion(frame) }
        }
    }

    func snap(_ window: AccessibleWindow, to frame: CGRect, token: CancellationToken,
              completion: @escaping @MainActor (Result<SnapResult, Error>) -> Void) {
        queue.async {
            guard !token.isCancelled else { return }
            window.writeToken = token
            defer { window.writeToken = nil }
            let result = Result { try SnapEngine.snap(window: window, to: frame, cancelled: { token.isCancelled }) }
            DispatchQueue.main.async { completion(result) }
        }
    }
}
