import SwiftUI

/// Peek-a-do — a menu bar only utility.
///
/// No Dock icon, no main window (`INFOPLIST_KEY_LSUIElement`). The menu bar item,
/// its popover, and the global toggle hotkey are all managed by `AppDelegate` —
/// `MenuBarExtra` can't be opened/closed from code, and we need a hotkey to do
/// exactly that.
@main
struct PeekADoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app has no scene of its own; keep an empty Settings scene so
        // SwiftUI is satisfied. It never shows for an LSUIElement app.
        Settings {
            EmptyView()
        }
    }
}
