import Cocoa

/// NSSound(named:)?.play() as a one-liner is a trap: play() is async and
/// returns immediately, so if nothing retains the NSSound instance beyond
/// that expression, ARC can deallocate it while CoreAudio is still playing
/// it — a use-after-free that corrupts the heap and crashes somewhere
/// unrelated later. Keep both sounds alive for the app's lifetime instead.
enum SoundPlayer {
    private static let success = NSSound(named: "Glass")
    private static let failure = NSSound(named: "Funk")

    static func playSuccess() {
        success?.stop()
        success?.play()
    }

    static func playFailure() {
        failure?.stop()
        failure?.play()
    }
}
