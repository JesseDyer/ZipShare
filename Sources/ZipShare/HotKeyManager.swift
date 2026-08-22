import Cocoa
import Carbon

/// Registers a system-wide hotkey using the old Carbon Events API.
/// This is still the standard no-dependency way to do global hotkeys
/// in a Cocoa app — Carbon.framework is deprecated but its hotkey
/// calls remain fully functional.
///
/// Default combo: Cmd+Shift+U.
/// To change it, edit `keyCode` below. Virtual keycodes are documented
/// in <Carbon/HIToolbox/Events.h> (kVK_ANSI_* constants).
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var handler: (() -> Void)?

    private let keyCode: UInt32 = 0x20 // kVK_ANSI_U
    private let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handler?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: fourCharCode("ZpUp"), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8 {
        result = (result << 8) + OSType(char)
    }
    return result
}
