import AppKit
import SwiftUI
import ApplicationServices

/// Owns the menu bar item, the popover that hosts `TaskListView`, the Settings
/// window, and the double-tap gesture that toggles the popover.
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
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingController(
            rootView: TaskListView(onOpenSettings: { [weak self] in self?.showSettings() })
        )
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = false

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "checklist",
                accessibilityDescription: "Peek-A-Do"
            )
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let prompt = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)

        doubleTap = DoubleTapMonitor(flag: Self.toggleModifier) { [weak self] in
            self?.togglePopover()
        }
    }

    // MARK: - Menu bar

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Peek-A-Do", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)   // opens the menu…
        statusItem.menu = nil                  // …and unhooks it so left-click still toggles
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - Settings window

    @objc private func showSettings() {
        if popover.isShown { popover.performClose(nil) }

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Peek-A-Do Settings"
            window.contentViewController = NSHostingController(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
