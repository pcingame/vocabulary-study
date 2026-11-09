import AVFoundation

@MainActor enum Speaker {
    // Cấu hình audio 1 lần (lúc đọc lần đầu): vẫn đọc khi bật im lặng, nhạc nền chỉ nhỏ đi lúc đọc.
    private static let synth: AVSpeechSynthesizer = {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
        let s = AVSpeechSynthesizer()
        s.delegate = finished
        return s
    }()
    private static let finished = Finished()

    /// Đọc xong thì trả audio lại để nhạc nền to lên như cũ.
    final class Finished: NSObject, AVSpeechSynthesizerDelegate {
        func speechSynthesizer(_ synth: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            if !synth.isSpeaking { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        }
    }

    static func say(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Settings.voice)
        utterance.rate = Float(Settings.speechRate)
        synth.speak(utterance)
    }
}
