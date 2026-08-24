import AppKit

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
// A menu bar utility has no windows and no reason to appear in the Dock or
// the Cmd+Tab switcher.
app.setActivationPolicy(.accessory)
app.run()
