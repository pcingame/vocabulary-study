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
            WordFront(word: word)
            if flipped { WordBack(word: word) }
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

/// Mặt trước thẻ: từ, phiên âm, nút nghe.
struct WordFront: View {
    let word: Word

    var body: some View {
        VStack(spacing: 8) {
            Text(word.term).font(.largeTitle.bold()).multilineTextAlignment(.center)
            if !word.ipa.isEmpty { Text(word.ipa).font(.title3).foregroundStyle(.secondary) }
            Button("Nghe phát âm", systemImage: "speaker.wave.2.fill") { Speaker.say(word.term) }
                .labelStyle(.iconOnly)
                .font(.title)
                .buttonStyle(.borderless)
        }
    }
}

/// Mặt sau thẻ: từ loại, nghĩa, câu ví dụ (chạm để nghe) và nghĩa câu ví dụ.
struct WordBack: View {
    let word: Word

    var body: some View {
        VStack(spacing: 8) {
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
                if !word.exampleMeaning.isEmpty {
                    Text(word.exampleMeaning).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Lật thẻ tự do theo chủ đề: vuốt để chuyển, chạm để lật. Không ảnh hưởng lịch ôn.
struct FlashcardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [Word]
    @State private var index = 0
    @State private var flipped = false

    init(words: [Word]) { _cards = State(initialValue: words) }

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(cards.indices, id: \.self) { i in
                    card(cards[i], flipped: i == index && flipped).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle("\(index + 1)/\(cards.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Trộn thẻ", systemImage: "shuffle") { cards.shuffle(); index = 0; flipped = false }
                }
            }
            .onChange(of: index, initial: true) {
                flipped = false
                if cards.indices.contains(index) { Speaker.say(cards[index].term) }
            }
        }
    }

    private func card(_ word: Word, flipped: Bool) -> some View {
        ZStack {
            VStack(spacing: 16) {
                WordFront(word: word)
                Text("Chạm để lật").font(.caption).foregroundStyle(.tertiary)
            }
            .opacity(flipped ? 0 : 1)
            WordBack(word: word)
                .padding()
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 24))
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .padding()
        .contentShape(.rect)
        .onTapGesture { withAnimation(.spring(duration: 0.4)) { self.flipped.toggle() } }
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
