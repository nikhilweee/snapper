import AppKit
import ApplicationServices
import SnapperCore

@MainActor
final class DragTracker {
    struct Destination {
        let display: Display
        let layout: Layout
    }

    /// Owns everything that must end together when a gesture finishes or is cancelled.
    @MainActor
    final class Gesture {
        enum Phase { case pressed, dragging, finishing, cancelled }

        private(set) var phase = Phase.pressed
        let token = CancellationToken()
        var target: (window: AccessibleWindow, motion: DragSession)?
        var sampleInFlight = false
        private(set) var timer: Timer?
        var isTracking: Bool { phase == .pressed || phase == .dragging }

        func drag(poll: @escaping @MainActor () -> Void) {
            guard isTracking else { return }
            phase = .dragging
            guard timer == nil else { return }
            let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard self?.phase == .dragging else { return }
                    poll()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func finish() -> Bool {
            guard isTracking else { return false }
            let wasDragging = phase == .dragging
            phase = .finishing
            stopPolling()
            return wasDragging
        }

        func cancel() {
            phase = .cancelled
            token.cancel()
            target = nil
            stopPolling()
        }

        private func stopPolling() {
            timer?.invalidate()
            timer = nil
        }
    }

    var destination: ((CGPoint) -> Destination?)?
    var primaryTop: (() -> CGFloat)?
    var report: ((String) -> Void)?
    var enabled = true { didSet { if !enabled { cancel() } } }
    private let worker = AccessibilityWorker()
    private let overlay = OverlayController()
    private var monitors: [Any] = []
    private var gesture: Gesture?

    func start() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            // Snapper's menus and alerts must never become drag targets.
            if event.type == .leftMouseDown { self?.cancel() }
            return event
        }) { monitors.append(monitor) }
    }

    func stop() {
        cancel()
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    func cancel() {
        gesture?.cancel()
        gesture = nil
        overlay.hide()
    }

    private func handle(_ event: NSEvent) {
        guard enabled, AXIsProcessTrusted() else { cancel(); return }
        switch event.type {
        case .leftMouseDown: begin()
        case .leftMouseDragged:
            guard let gesture else { return }
            gesture.drag { [weak self] in self?.sample() }
            updateOverlay()
        case .flagsChanged: updateOverlay()
        case .leftMouseUp: finish(shift: event.modifierFlags.contains(.shift), pointer: NSEvent.mouseLocation)
        default: break
        }
    }

    private func begin() {
        cancel()
        let gesture = Gesture()
        self.gesture = gesture
        let point = Geometry.accessibilityPoint(from: NSEvent.mouseLocation, primaryTop: primaryTop?() ?? 0)
        worker.resolve(at: point, token: gesture.token) { [weak self] target, frame in
            guard let self, self.gesture === gesture, gesture.isTracking else { return }
            guard let target, let frame else { self.cancel(); return }
            gesture.target = (target, DragSession(initialFrame: frame))
        }
    }

    private func sample() {
        guard let gesture, gesture.phase == .dragging, !gesture.sampleInFlight,
              let target = gesture.target else { return }
        // If another application consumes mouse-up, do not leave a live preview behind.
        guard NSEvent.pressedMouseButtons & 1 != 0 else { cancel(); return }
        gesture.sampleInFlight = true
        worker.inspect(target.window, token: gesture.token) { [weak self] frame in
            guard let self, self.gesture === gesture, gesture.isTracking else { return }
            gesture.sampleInFlight = false
            guard let frame else { self.cancel(); return }
            gesture.target?.motion.sample(frame: frame)
            self.updateOverlay()
        }
    }

    private func updateOverlay() {
        let point = NSEvent.mouseLocation
        guard let gesture, gesture.phase == .dragging,
              gesture.target?.motion.canPreview(shift: NSEvent.modifierFlags.contains(.shift)) == true,
              let destination = destination?(point) else { overlay.hide(); return }
        overlay.show(layout: destination.layout, on: destination.display, pointer: point)
    }

    private func finish(shift: Bool, pointer: CGPoint) {
        guard let gesture, gesture.isTracking else { return }
        let wasDragging = gesture.finish()
        overlay.hide()
        guard wasDragging, shift, let target = gesture.target else { cancel(); return }
        // Queue a fresh read after any outstanding sample before committing.
        worker.inspect(target.window, token: gesture.token, checkEligibility: true) { [weak self] frame in
            guard let self, self.gesture === gesture, gesture.phase == .finishing else { return }
            guard let frame else { self.cancel(); return }
            gesture.target?.motion.sample(frame: frame)
            guard let destination = self.destination?(pointer),
                  let zone = Geometry.selectedZone(at: pointer, layout: destination.layout, usableFrame: destination.display.usableFrame),
                  gesture.target?.motion.canCommit(shift: shift, pointerInsideZone: true) == true else { self.cancel(); return }
            let rect = Geometry.rectangle(for: zone, in: destination.display.usableFrame)
            let axRect = Geometry.accessibilityRect(from: rect, primaryTop: self.primaryTop?() ?? 0)
            self.worker.snap(target.window, to: axRect, token: gesture.token) { [weak self] result in
                guard let self, self.gesture === gesture, gesture.phase == .finishing else { return }
                switch result {
                case .success(.constrained): self.report?("The app limited this window's size or position.")
                case .failure(let error): self.report?(error.localizedDescription)
                default: break
                }
                self.cancel()
            }
        }
    }
}
