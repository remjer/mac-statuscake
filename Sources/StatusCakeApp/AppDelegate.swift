import AppKit
import SwiftUI
import StatusCakeCore

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
