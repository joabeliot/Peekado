import AppKit
import SwiftUI
import Carbon.HIToolbox

/// Owns the menu bar item, the popover that hosts `TaskListView`, and the global
/// hotkey that toggles it.
///
/// `MenuBarExtra` can't be opened/closed programmatically, so the menu bar piece
/// is built by hand on `NSStatusItem` + `NSPopover`.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Toggle hotkey — change these two lines to rebind.
    // ⌥⌘Space alone is macOS's "Finder search", so control is added.
    private static let hotKeyCode = kVK_Space
    private static let hotKeyModifiers: NSEvent.ModifierFlags = [.control, .option, .command]

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var hotKey: GlobalHotKey?

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

        hotKey = GlobalHotKey(
            keyCode: Self.hotKeyCode,
            modifiers: Self.hotKeyModifiers
        ) { [weak self] in
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
