import AppKit
import ApplicationServices
import OSLog
import SnapperCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum SuspensionReason { case systemSleep, displaySleep, inactiveSession }

    private let displays = Displays()
    private let tracker = DragTracker()
    private var configuration: ConfigurationStore?
    private var assignments: AssignmentStore?
    private var activeConfiguration: Configuration { configuration?.current ?? .starter }
    private var statusItem: NSStatusItem?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var permissionTimer: Timer?
    private var trusted = false
    private var paused = false
    private var suspensions = Set<SuspensionReason>()
    private var latestIssue: String?
    private var stateIssue: String?
    private let logger = Logger(subsystem: "com.nikhilweee.snapper", category: "app")
    private let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Snapper", isDirectory: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            configuration = try ConfigurationStore(url: directory.appendingPathComponent("config.json"))
        } catch { record("Configuration could not be loaded. Using starter layouts until you fix and reload config.json. \(error.localizedDescription)") }
        do {
            assignments = try AssignmentStore(url: directory.appendingPathComponent("state.json"))
        } catch {
            let message = "Display memory unavailable. Fix or move state.json and relaunch: \(error.localizedDescription)"
            stateIssue = message
            record(message)
        }
        displays.refresh()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem
        statusItem.button?.image = MenuBarIcon.makeImage()
        statusItem.button?.toolTip = "Snapper — hold Shift while dragging a window"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        tracker.destination = { [weak self] point in
            guard let self, let display = self.displays.display(at: point),
                  case .layout(let id) = self.choice(for: display),
                  let layout = self.activeConfiguration.layouts.first(where: { $0.id == id }) else { return nil }
            return DragTracker.Destination(display: display, layout: layout)
        }
        tracker.primaryTop = { [weak self] in self?.displays.primaryTop ?? 0 }
        tracker.report = { [weak self] in self?.record($0) }
        tracker.start()
        installObservers()
        updatePermission()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePermission() }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
        if !trusted {
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.stop()
        permissionTimer?.invalidate()
        for (center, observer) in observers { center.removeObserver(observer) }
    }

    private func installObservers() {
        observe(.default, NSApplication.didChangeScreenParametersNotification) { [weak self] in
            self?.tracker.cancel()
            self?.displays.refresh()
        }
        let workspace = NSWorkspace.shared.notificationCenter
        let suspendEvents: [(Notification.Name, SuspensionReason)] = [
            (NSWorkspace.willSleepNotification, .systemSleep),
            (NSWorkspace.screensDidSleepNotification, .displaySleep),
            (NSWorkspace.sessionDidResignActiveNotification, .inactiveSession)
        ]
        for (name, reason) in suspendEvents {
            observe(workspace, name) { [weak self] in
                self?.suspensions.insert(reason)
                self?.updatePermission()
            }
        }
        let resumeEvents: [(Notification.Name, SuspensionReason)] = [
            (NSWorkspace.didWakeNotification, .systemSleep),
            (NSWorkspace.screensDidWakeNotification, .displaySleep),
            (NSWorkspace.sessionDidBecomeActiveNotification, .inactiveSession)
        ]
        for (name, reason) in resumeEvents {
            observe(workspace, name) { [weak self] in
                self?.suspensions.remove(reason)
                self?.tracker.cancel()
                self?.displays.refresh()
                self?.updatePermission()
            }
        }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] in self?.tracker.cancel() }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping @MainActor () -> Void) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { action() }
        }
        observers.append((center, observer))
    }

    private func choice(for display: Display) -> LayoutChoice {
        assignments?.effectiveChoice(for: display.uuid, configuration: activeConfiguration)
            ?? .layout(activeConfiguration.defaultLayoutId)
    }

    private func updatePermission() {
        trusted = AXIsProcessTrusted()
        tracker.enabled = trusted && !paused && suspensions.isEmpty
        statusItem?.button?.appearsDisabled = paused || !trusted
    }

    private func record(_ message: String) {
        latestIssue = message
        logger.error("\(message, privacy: .public)")
        statusItem?.button?.toolTip = "Snapper: \(message)"
    }

    func menuWillOpen(_ menu: NSMenu) {
        updatePermission()
        menu.removeAllItems()
        menu.autoenablesItems = false
        let heading = NSMenuItem(title: "Snapper", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        add("\(paused ? "Enable" : "Pause") Snapper", action: #selector(togglePause), to: menu)
        menu.addItem(.separator())
        for (index, display) in displays.connected.enumerated() {
            let item = NSMenuItem(title: "\(display.name) (\(index + 1))", action: nil, keyEquivalent: "")
            item.toolTip = display.uuid ?? display.identityIssue
            item.submenu = makeDisplayMenu(for: display)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        add("Open Configuration", action: #selector(openConfiguration), to: menu)
        add("Reload Configuration", action: #selector(reloadConfiguration), to: menu)
        if !trusted {
            add("Accessibility: Permission Needed", action: #selector(openAccessibility), to: menu)
        }
        if let latestIssue {
            menu.addItem(.separator())
            let item = add("Show Last Issue", action: #selector(showIssue), to: menu)
            item.toolTip = latestIssue
        }
        menu.addItem(.separator())
        add("About Snapper", action: #selector(showAbout), to: menu)
        add("Quit Snapper", action: #selector(quit), key: "q", to: menu)
    }

    private func makeDisplayMenu(for display: Display) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if let issue = display.identityIssue { addInformation(issue, to: menu) }
        if let stateIssue { addInformation(stateIssue, to: menu) }
        let current = choice(for: display)
        let choices: [(String, LayoutChoice)] = [("Off", .off)] + activeConfiguration.layouts.map { ($0.name, .layout($0.id)) }
        for (title, choice) in choices {
            let entry = add(title, action: #selector(selectLayout(_:)), to: menu)
            entry.state = current == choice ? .on : .off
            entry.isEnabled = display.uuid != nil && assignments != nil
            entry.representedObject = LayoutSelection(uuid: display.uuid, choice: choice)
        }
        if let uuid = display.uuid, case .layout(let savedID) = assignments?.savedChoice(for: uuid),
           !activeConfiguration.layouts.contains(where: { $0.id == savedID }) {
            addInformation("Saved '\(savedID)' is missing; using the default.", to: menu)
        }
        return menu
    }

    @discardableResult
    private func add(_ title: String, action: Selector, key: String = "", to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    private func addInformation(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @objc private func togglePause() {
        paused.toggle()
        updatePermission()
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? LayoutSelection, let uuid = selection.uuid,
              displays.connected.contains(where: { $0.uuid == uuid }), let assignments else { return }
        tracker.cancel()
        do { try assignments.set(selection.choice, for: uuid) }
        catch { record("Could not save display layout: \(error.localizedDescription)"); showIssue() }
    }

    @objc private func openConfiguration() {
        let url = directory.appendingPathComponent("config.json")
        if !NSWorkspace.shared.open(url) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    @objc private func reloadConfiguration() {
        tracker.cancel()
        do {
            if let configuration {
                try configuration.reload()
            } else {
                configuration = try ConfigurationStore(url: directory.appendingPathComponent("config.json"))
            }
            latestIssue = stateIssue
            statusItem?.button?.toolTip = "Snapper — configuration reloaded"
        } catch {
            record("Could not reload config.json. Previous layouts remain active. \(error.localizedDescription)")
            showIssue()
        }
    }

    private func showOnboarding() {
        let alert = NSAlert()
        alert.messageText = "Allow Window Snapping"
        alert.informativeText = "Snapper requires accessibility permissions to move and resize windows. Enable Snapper in System Settings → Privacy & Security → Accessibility."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { openAccessibility() }
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showIssue() {
        guard let latestIssue else { return }
        let alert = NSAlert()
        alert.messageText = "Snapper"
        alert.informativeText = latestIssue
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func showAbout() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSAttributedString(string: "GitHub", attributes: [
            .link: "https://github.com/nikhilweee/snapper",
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .paragraphStyle: paragraph
        ])
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

private final class LayoutSelection {
    let uuid: String?
    let choice: LayoutChoice
    init(uuid: String?, choice: LayoutChoice) { self.uuid = uuid; self.choice = choice }
}
