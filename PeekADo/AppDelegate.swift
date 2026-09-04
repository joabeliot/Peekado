import AppKit
import SwiftUI
import ApplicationServices

/// Owns the menu bar item, the popover that hosts `TaskListView`, and the
/// double-tap gesture that toggles it.
///
/// `MenuBarExtra` can't be opened/closed programmatically, so the menu bar piece
/// is built by hand on `NSStatusItem` + `NSPopover`.
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// The modifier you double-tap to toggle the popover. Change this one line
    /// to rebind (e.g. `.command`, `.option`).
    private static let toggleModifier: NSEvent.ModifierFlags = .control

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var doubleTap: DoubleTapMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingController(rootView: TaskListView())
        hosting.sizingOptions = [.preferredContentSize]  // popover follows the view's height
        popover.contentViewController = hosting
        popover.behavior = .transient                    // click-away closes it
        popover.animates = false

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "checklist",
                accessibilityDescription: "Peek-A-Do"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Ask for Accessibility up front (the global key monitor needs it).
        let prompt = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)

        doubleTap = DoubleTapMonitor(flag: Self.toggleModifier) { [weak self] in
            self?.togglePopover()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
