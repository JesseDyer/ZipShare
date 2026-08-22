import Cocoa

/// A borderless, auto-dismissing HUD-style toast. Used instead of
/// UNUserNotificationCenter, which is unreliable for unsigned locally-built
/// apps (Notification Center is picky about app identity/signing outside
/// the App Store). This needs zero permissions and just works.
final class ToastWindow: NSWindow {
    init(message: String) {
        let width: CGFloat = 340
        let height: CGFloat = 56

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        // We manage this window's lifetime via ARC (ToastController holds the
        // only strong reference) rather than -close, so make sure AppKit
        // doesn't also try to release it out from under us.
        isReleasedWhenClosed = false

        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.material = .hudWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true

        let label = NSTextField(wrappingLabelWithString: message)
        label.frame = NSRect(x: 16, y: 8, width: width - 32, height: height - 16)
        label.alignment = .center
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.usesSingleLineMode = false
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2

        container.addSubview(label)
        contentView = container

        positionNearMenuBar(width: width, height: height)
    }

    private func positionNearMenuBar(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - width - 20
        let y = screenFrame.maxY - 20 - height
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

final class ToastController {
    static let shared = ToastController()
    private var currentWindow: ToastWindow?

    func show(_ message: String, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            // Don't call close() on a window that might still have an
            // animator-driven animation in flight — order it out and drop
            // our reference instead, letting ARC deallocate it once the
            // animation machinery is done with it.
            if let existing = self.currentWindow {
                existing.animator().alphaValue = 0
                existing.orderOut(nil)
                self.currentWindow = nil
            }

            let window = ToastWindow(message: message)
            window.alphaValue = 0
            window.orderFrontRegardless()
            self.currentWindow = window

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                window.animator().alphaValue = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                guard self.currentWindow === window else { return }
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.3
                    window.animator().alphaValue = 0
                }, completionHandler: {
                    guard self.currentWindow === window else { return }
                    window.orderOut(nil)
                    self.currentWindow = nil
                })
            }
        }
    }
}
