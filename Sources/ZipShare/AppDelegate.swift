import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        print("[ZipShare] status bar item created")

        HotKeyManager.shared.handler = {
            UploadCoordinator.shared.uploadClipboard()
        }
        HotKeyManager.shared.register()
        print("[ZipShare] hotkey registered (⌘⇧U)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }
}
