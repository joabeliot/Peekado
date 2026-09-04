import AppKit

/// Fires `action` when `flag` (one modifier key) is tapped twice within
/// `interval`, with no other key or click in between — the "double-tap ⌘ opens
/// Siri" gesture.
///
/// Uses a global `NSEvent` monitor, which only delivers events once the app is
/// trusted for **Accessibility**. Until then this silently does nothing and the
/// menu bar click stays the way in.
final class DoubleTapMonitor {

    private let flag: NSEvent.ModifierFlags
    private let interval: TimeInterval
    private let action: () -> Void

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastTap: TimeInterval = 0

    private static let relevant: NSEvent.ModifierFlags = [.control, .option, .command, .shift]

    init(flag: NSEvent.ModifierFlags,
         interval: TimeInterval = 0.4,
         action: @escaping () -> Void) {
        self.flag = flag
        self.interval = interval
        self.action = action

        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        // Local monitor so it also works while Peek-A-Do's own popover is key.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    deinit {
        [globalMonitor, localMonitor].compactMap { $0 }.forEach(NSEvent.removeMonitor)
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .flagsChanged else {
            lastTap = 0            // any real keypress or click breaks the run
            return
        }

        let active = event.modifierFlags.intersection(Self.relevant)

        if active == flag {
            // target modifier went down on its own
            if event.timestamp - lastTap <= interval {
                lastTap = 0
                action()
            } else {
                lastTap = event.timestamp
            }
        } else if !active.isEmpty {
            lastTap = 0            // some other modifier / combo — not a clean tap
        }
        // active empty == release: keep lastTap so the next press can pair with it
    }
}
