import AppKit
import SwiftUI
import StatusCakeCore
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var escMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // squareLength fixes a frame too narrow for the detail text next to
        // the icon (e.g. "3/10"); variableLength lets the item grow to fit it.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: BarIcon.unknown.sfSymbolName, accessibilityDescription: "StatusCake")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            // MenuBarExtra cannot tell left, middle and right clicks apart;
            // that is the whole reason this app uses NSStatusItem directly.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp, .otherMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverContentView(model: model))

        model.onUpdate = { [weak self] summary in
            self?.render(summary)
        }

        NotificationDelivery.setDelegate(self)
        NotificationDelivery.requestAuthorization()

        // Polling only runs while the process is awake; without this, a
        // check that flipped during sleep waits out however much of the
        // interval is left after wake instead of being caught immediately.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.model.forceRefresh()
            }
        }

        model.start()
    }

    private func render(_ summary: Summary) {
        guard let button = statusItem.button else { return }
        let bar = barLabel(for: summary)
        button.image = NSImage(systemSymbolName: bar.icon.sfSymbolName, accessibilityDescription: "StatusCake")
        button.image?.isTemplate = true
        button.contentTintColor = (bar.urgent || bar.error) ? .systemRed : nil
        button.title = bar.detail.isEmpty ? "" : " \(bar.detail)"
        button.toolTip = tooltipText(summary)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        switch NSApp.currentEvent?.type {
        case .leftMouseUp:
            togglePopover()
        case .rightMouseUp:
            NSWorkspace.shared.open(URL(string: "https://app.statuscake.com")!)
        case .otherMouseUp:
            model.forceRefresh()
        default:
            break
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            installEscMonitor()
        }
    }

    // NSPopover's own outside-click dismissal covers most cases, but a
    // layer-shell popup does not otherwise see Esc unless something asks for
    // key events -- see the reference's own notes on this exact pitfall on
    // Linux; AppKit's local event monitor is the macOS equivalent fix.
    //
    // Esc means "go back" while settings is open, and "close" while the
    // check list is up -- the same two-deep behaviour the reference's own
    // panel has.
    private func installEscMonitor() {
        // popoverDidClose (which clears escMonitor) fires asynchronously
        // after the close animation, so isShown can already read false
        // before it does. Without this, re-triggering the status item in
        // that window would install a second monitor over the first one,
        // leaking it and leaving two Escape handlers active at once.
        removeEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53 else { return event } // Escape
            if self.model.showingSettings {
                self.model.showingSettings = false
            } else {
                self.popover.performClose(nil)
            }
            return nil
        }
    }

    private func removeEscMonitor() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        removeEscMonitor()
        // The panel always comes back up on the check list, never wherever
        // it happened to be left.
        model.showingSettings = false
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // With no window ever active, the default "only show it once
    // foreground" heuristic would still show these -- .banner is set
    // explicitly anyway so notifications are never quietly suppressed by
    // some future window this app doesn't currently have.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
