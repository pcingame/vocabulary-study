import SwiftUI
import SwiftData
import AVFoundation

struct StudyView: View {
    let topic: Topic?
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    @State private var queue: [Word] = []
    @State private var loaded = false
    @State private var flipped = false

    var body: some View {
        NavigationStack {
            Group {
                if let word = queue.first {
                    card(word)
                } else if loaded {
                    ContentUnavailableView("Xong rồi! 🎉", systemImage: "checkmark.seal.fill",
                                           description: Text("Hẹn gặp lại ngày mai."))
                }
            }
            .navigationTitle(queue.isEmpty ? "" : "Còn \(queue.count) thẻ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Đóng") { dismiss() } }
            .onAppear {
                guard !loaded else { return }
                queue = Word.todayQueue(topic?.words ?? allWords)
                loaded = true
            }
        }
    }

    private func card(_ word: Word) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text(word.term).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Button("Nghe phát âm", systemImage: "speaker.wave.2.fill") { Speaker.say(word.term) }
                .labelStyle(.iconOnly)
                .font(.title)
            if flipped {
                if !word.pos.isEmpty { Text(word.pos).italic().foregroundStyle(.secondary) }
                Text(word.meaning).font(.title2).multilineTextAlignment(.center)
                if !word.example.isEmpty {
                    Button { Speaker.say(word.example) } label: {
                        Label(word.example, systemImage: "speaker.wave.1")
                            .italic()
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top)
                }
            }
            Spacer()
            if flipped {
                HStack {
                    Button { answer(false) } label: { Text("Quên").frame(maxWidth: .infinity) }.tint(.red)
                    Button { answer(true) } label: { Text("Nhớ").frame(maxWidth: .infinity) }.tint(.green)
                }
            } else {
                Button { flipped = true } label: { Text("Xem nghĩa").frame(maxWidth: .infinity) }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .task(id: word.persistentModelID) { Speaker.say(word.term) }
    }

    private func answer(_ remembered: Bool) {
        let word = queue.removeFirst()
        word.answer(remembered: remembered)
        if !remembered { queue.append(word) }  // quên thì học lại cuối buổi
        flipped = false
        Streak.record()
    }
}

@MainActor enum Speaker {
    private static let synth = AVSpeechSynthesizer()

    static func say(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback)  // vẫn đọc khi bật chế độ im lặng
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utterance)
    }
}
