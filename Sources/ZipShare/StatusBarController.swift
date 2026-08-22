import Cocoa

final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var settingsWindowController: SettingsWindowController?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip.circle", accessibilityDescription: "ZipShare")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Upload Clipboard (⌘⇧U)", action: #selector(uploadFromMenu), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit ZipShare", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func uploadFromMenu() {
        UploadCoordinator.shared.uploadClipboard()
    }

    @objc private func openPreferences() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
