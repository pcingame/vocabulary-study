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
    @State private var answeredCount = 0  // đổi id thẻ gõ để reset ô nhập, kể cả khi gặp lại đúng từ vừa quên
    @AppStorage("studyMode") private var mode = StudyMode.flip
    @State private var drag = 0.0  // độ kéo ngang của thẻ
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Vuốt đủ xa (≥ 100pt) sau khi lật thẻ: phải = Dễ, trái = Quên. Chưa đủ xa thì thẻ bật về chỗ cũ.
    static func swipeDecision(_ dx: Double, threshold: Double = 100) -> Word.Grade? {
        dx >= threshold ? .easy : dx <= -threshold ? .forgot : nil
    }

    var body: some View {
        NavigationStack {
            // Color.clear giữ cho view luôn có nội dung, nếu không onAppear không chạy khi hàng đợi còn rỗng.
            ZStack {
                Color.clear
                if let word = queue.first {
                    ProgressView(value: Double(answeredCount), total: Double(answeredCount + queue.count))
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal)
                    switch mode {
                    case .flip: card(word)
                    case .typing, .listening:
                        TypingCard(word: word, listening: mode == .listening) { answer($0) }.id(answeredCount)
                    case .choice:
                        if let choices = Answer.choices(for: word, pool: word.topic?.words ?? [], fallback: allWords) {
                            ChoiceCard(word: word, choices: choices) { answer($0) }.id(answeredCount)
                        } else {
                            card(word)  // chưa đủ 4 nghĩa khác nhau
                        }
                    }
                } else if loaded {
                    ContentUnavailableView("Xong rồi! 🎉", systemImage: "checkmark.seal.fill",
                                           description: Text("Hẹn gặp lại ngày mai."))
                }
            }
            .navigationTitle(queue.isEmpty ? "" : "Còn \(queue.count) thẻ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Đóng") { dismiss() }.accessibilityIdentifier("studyClose") }
            .onAppear {
                guard !loaded else { return }
                queue = Word.todayQueue(topic?.words ?? allWords)
                loaded = true
            }
        }
    }

    private func card(_ word: Word) -> some View {
        VStack(spacing: 20) {
            FlipCard(word: word, flipped: flipped)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(drag > 0 ? Color.green : .red)
                        .opacity(min(0.35, abs(drag) / 300))
                        .allowsHitTesting(false)
                }
                .offset(x: drag)
                .rotationEffect(.degrees(reduceMotion ? 0 : drag / 20))
                .onTapGesture { flip() }
                .gesture(DragGesture()
                    .onChanged { if flipped && !reduceMotion { drag = $0.translation.width } }
                    .onEnded { endSwipe($0.translation.width) })
                .accessibilityIdentifier("studyCard")
                .id(answeredCount)
                .transition(reduceMotion ? .opacity
                            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            if flipped {
                HStack {
                    Button { answer(.forgot) } label: { Text("Quên").frame(maxWidth: .infinity) }.tint(.red)
                        .accessibilityIdentifier("answerForget")
                    Button { answer(.hard) } label: { Text("Khó").frame(maxWidth: .infinity) }.tint(.orange)
                        .accessibilityIdentifier("answerHard")
                    Button { answer(.easy) } label: { Text("Dễ").frame(maxWidth: .infinity) }.tint(.green)
                        .accessibilityIdentifier("answerEasy")
                }
            } else {
                Button { flip() } label: { Text("Xem nghĩa").frame(maxWidth: .infinity) }
                    .accessibilityIdentifier("revealAnswer")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .padding(.top, 8)
        .sensoryFeedback(.impact(weight: .light), trigger: answeredCount)
        .task(id: answeredCount) { Speaker.say(word.term) }
    }

    private func flip() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4)) { flipped = true }
    }

    private func endSwipe(_ dx: Double) {
        guard let grade = Self.swipeDecision(dx) else {
            withAnimation(.spring) { drag = 0 }
            return
        }
        withAnimation(.easeIn(duration: 0.2)) { drag = dx > 0 ? 700 : -700 } completion: { answer(grade) }
    }

    private func answer(_ grade: Word.Grade) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35)) {
            let word = queue.removeFirst()
            word.answer(grade)
            if grade == .forgot { queue.append(word) }  // quên thì học lại cuối buổi
            answeredCount += 1
            flipped = false
            drag = 0
        }
        Streak.record()
        StudyLog.record()
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
        FlipCard(word: word, flipped: flipped)
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
        utterance.voice = AVSpeechSynthesisVoice(language: Settings.voice)
        utterance.rate = Float(Settings.speechRate)
        synth.speak(utterance)
    }
}

/// Thẻ lật 3D: mặt trước là từ, mặt sau là từ + nghĩa + ví dụ. Bật Reduce Motion thì chỉ mờ dần.
struct FlipCard: View {
    let word: Word
    let flipped: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                WordFront(word: word)
                Text("Chạm để lật").font(.caption).foregroundStyle(.tertiary)
            }
            .opacity(flipped ? 0 : 1)
            VStack(spacing: 12) {
                Text(word.term).font(.title.bold())
                WordBack(word: word)
            }
            .padding()
            .opacity(flipped ? 1 : 0)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 24))
        .rotation3DEffect(.degrees(flipped && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }
}
