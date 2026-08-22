import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory apps have no Dock icon and no menu bar app menu — just the
// status item. This is the runtime equivalent of setting LSUIElement
// in Info.plist; we set both for good measure.
app.setActivationPolicy(.accessory)
app.run()
