import AVFoundation

/// Video sound and Live Photo audio need an active playback session; mixing
/// keeps the user's music alive instead of stopping it.
enum AudioSession {
    static func activatePlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
