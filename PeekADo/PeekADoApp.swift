import SwiftUI

/// Peek-a-do — a menu bar only utility.
///
/// There is no Dock icon and no main window (see `INFOPLIST_KEY_LSUIElement`
/// in the target's build settings). The whole app is the `MenuBarExtra` below.
@main
struct PeekADoApp: App {
    var body: some Scene {
        MenuBarExtra {
            TaskListView()
        } label: {
            Image(systemName: "checklist")
        }
        // `.window` gives us a real inline SwiftUI view in the dropdown,
        // not a plain AppKit menu.
        .menuBarExtraStyle(.window)
    }
}
