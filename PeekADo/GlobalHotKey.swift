import AppKit
import Carbon.HIToolbox

/// A single system-wide hotkey, via Carbon's `RegisterEventHotKey`.
///
/// Works for an `LSUIElement` app whether or not it's frontmost, and needs **no**
/// Accessibility / Input Monitoring permission. The C event handler can't carry
/// context, so live instances are looked up by id in a static table.
final class GlobalHotKey {

    private let id: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    private static var instances: [UInt32: GlobalHotKey] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    /// - Parameters:
    ///   - keyCode: a virtual key code, e.g. `kVK_Space`, `kVK_ANSI_P`.
    ///   - modifiers: Cocoa modifier flags; translated to Carbon internally.
    init?(keyCode: Int, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        self.id = GlobalHotKey.nextID
        self.action = action
        GlobalHotKey.nextID += 1

        GlobalHotKey.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x504B4441 /* 'PKDA' */), id: id)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            GlobalHotKey.carbonModifiers(from: modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { return nil }
        GlobalHotKey.instances[id] = self
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        GlobalHotKey.instances[id] = nil
    }

    // MARK: - Carbon plumbing

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                GlobalHotKey.instances[hkID.id]?.action()
                return noErr
            },
            1,
            &spec,
            nil,
            nil
        )
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option)  { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
        return mods
    }
}
