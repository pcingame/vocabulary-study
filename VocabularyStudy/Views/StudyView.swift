import SwiftUI
import SwiftData

struct StudyView: View {
    let topic: Topic?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var fallback: [Word] = []  // nghĩa nhiễu cho trắc nghiệm khi chủ đề quá ít từ
    @State private var session = StudySession()
    @State private var loaded = false
    @State private var flipped = false
    @AppStorage(Settings.studyModeKey) private var mode = StudyMode.flip
    @State private var drag = 0.0  // độ kéo ngang của thẻ
    @State private var streakBefore = 0
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
                if let word = session.queue.first {
                    ProgressView(value: Double(session.answered), total: Double(session.answered + session.queue.count))
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal)
                    switch mode {
                    case .flip: card(word)
                    case .typing, .listening:
                        TypingCard(word: word, listening: mode == .listening) { answer($0) }.id(session.answered)
                    case .choice:
                        if let choices = Answer.choices(for: word, pool: word.topic?.words ?? [], fallback: fallback) {
                            ChoiceCard(word: word, choices: choices) { answer($0) }.id(session.answered)
                        } else {
                            card(word)  // chưa đủ 4 nghĩa khác nhau
                        }
                    }
                } else if loaded {
                    if session.summary.wordCount == 0 {
                        ContentUnavailableView {
                            Label("Xong rồi! 🎉", systemImage: "checkmark.seal.fill")
                        } description: {
                            Text("Hẹn gặp lại ngày mai.")
                        } actions: {
                            if !practicePool.isEmpty { practiceButton }
                        }
                    } else {
                        SummaryView(summary: session.summary, streakBefore: streakBefore) { practiceButton }
                    }
                }
            }
            .paperBackground()
            .navigationTitle(session.queue.isEmpty ? "" : (session.practice ? "Luyện thêm · " : "") + "Còn \(session.queue.count) thẻ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Đóng") { dismiss() }.accessibilityIdentifier("studyClose") }
            .onDisappear { try? context.save() }  // lưu ngay để tab Hôm nay fetch thấy đúng tiến độ
            .onAppear {
                guard !loaded else { return }
                session.queue = topic.map { Word.todayQueue($0.words) } ?? Word.todayQueue(in: context)
                var some = FetchDescriptor<Word>()
                some.fetchLimit = 50
                fallback = (try? context.fetch(some)) ?? []
                streakBefore = Streak.display(current: UserDefaults.standard.integer(forKey: Settings.streakKey), last: Streak.lastStudy)
                loaded = true
            }
        }
    }

    /// Từ để luyện thêm: các từ vừa gặp trong buổi; chưa gặp từ nào thì lấy từ đã học (của chủ đề, hoặc 20 từ học gần nhất).
    private var practicePool: [Word] {
        if !session.summary.words.isEmpty { return session.summary.words }
        if let topic { return topic.words.filter { $0.learnedAt != nil } }
        var d = FetchDescriptor<Word>(predicate: #Predicate { $0.learnedAt != nil }, sortBy: [SortDescriptor(\.learnedAt, order: .reverse)])
        d.fetchLimit = 20
        return (try? context.fetch(d)) ?? []
    }

    private var practiceButton: some View {
        Button("Luyện thêm", systemImage: "arrow.clockwise") {
            let words = practicePool
            withAnimation { session = .practice(words) }
        }
        .pastelProminent()
        .controlSize(.large)
        .accessibilityIdentifier("practiceMore")
    }

    private func card(_ word: Word) -> some View {
        VStack(spacing: 20) {
            FlipCard(word: word, flipped: flipped)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(drag > 0 ? Color.easy : .forgot)
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
                .id(session.answered)
                .transition(reduceMotion ? .opacity
                            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            if flipped {
                HStack {
                    Button { answer(.forgot) } label: { Text("Quên").frame(maxWidth: .infinity) }.pastelProminent(.forgot)
                        .accessibilityIdentifier("answerForget")
                    Button { answer(.hard) } label: { Text("Khó").frame(maxWidth: .infinity) }.pastelProminent(.hard)
                        .accessibilityIdentifier("answerHard")
                    Button { answer(.easy) } label: { Text("Dễ").frame(maxWidth: .infinity) }.pastelProminent(.easy)
                        .accessibilityIdentifier("answerEasy")
                }
            } else {
                Button { flip() } label: { Text("Xem nghĩa").frame(maxWidth: .infinity) }
                    .accessibilityIdentifier("revealAnswer")
            }
        }
        .pastelProminent()
        .controlSize(.large)
        .padding()
        .padding(.top, 8)
        .sensoryFeedback(.impact(weight: .light), trigger: session.answered)
        .task(id: session.answered) { Speaker.say(word.term) }
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
            session.answer(grade)
            flipped = false
            drag = 0
        }
        Streak.record()
        if !session.practice { StudyLog.record() }  // luyện thêm không tính vào số thẻ hôm nay
    }
}

struct SummaryView<Actions: View>: View {
    let summary: SessionSummary
    let streakBefore: Int
    @ViewBuilder var actions: Actions
    @AppStorage(Settings.streakKey) private var streak = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let after = Streak.display(current: streak, last: Streak.lastStudy)
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(.tint)
                Text("Xong rồi! 🎉").font(.title.bold())
                Text("Đã học \(summary.wordCount) từ").font(.title3)
                HStack {
                    stat("Dễ", summary.count(.easy), .easyInk)
                    stat("Khó", summary.count(.hard), .hardInk)
                    stat("Quên", summary.count(.forgot), .forgotInk)
                }
                Label("Chuỗi: \(after) ngày" + (after > streakBefore ? " (+\(after - streakBefore))" : ""), systemImage: "leaf.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                if !summary.forgotten.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Từ cần chú ý").font(.headline)
                        ForEach(summary.forgotten) { word in
                            HStack {
                                Text(word.term).bold()
                                Spacer()
                                Text(word.meaning).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    .padding()
                    .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 16))
                }
                actions
                Text("Hẹn gặp lại ngày mai.").foregroundStyle(.secondary)
            }
            .padding()
        }
        .overlay {
            if after > streakBefore && SessionSummary.milestones.contains(after) && !reduceMotion {
                Confetti().allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }

    private func stat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack {
            Text("\(value)").font(.title.bold()).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Pháo giấy rơi trong ~3 giây, vẽ bằng Canvas.
struct Confetti: View {
    @State private var start = Date.now
    private let pieces = (0..<80).map { _ in
        (x: Double.random(in: 0...1), speed: Double.random(in: 0.25...0.6), spin: Double.random(in: -6...6),
         delay: Double.random(in: 0...0.8), color: [Color.orange, .pink, .yellow, .green, .blue, .purple].randomElement()!)
    }

    var body: some View {
        TimelineView(.animation(paused: Date.now.timeIntervalSince(start) > 4)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces where t > p.delay {
                    let y = (t - p.delay) * p.speed * size.height - 20
                    guard y < size.height + 20 else { continue }
                    var piece = context
                    piece.translateBy(x: p.x * size.width + sin(t * 3 + p.spin) * 20, y: y)
                    piece.rotate(by: .radians(t * p.spin))
                    piece.fill(Path(CGRect(x: -4, y: -6, width: 8, height: 12)), with: .color(p.color))
                }
            }
        }
        .ignoresSafeArea()
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
            .paperBackground()
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
        // Cả thẻ là 1 phần tử cho VoiceOver, chỉ đọc mặt đang hiện (mặt úp vẫn nằm trong cây view nên phải gộp).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(flipped ? [word.term, word.pos, word.meaning, word.example].filter { !$0.isEmpty }.joined(separator: ", ")
                                    : [word.term, word.ipa].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityHint(flipped ? "" : "Chạm hai lần để lật")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Nghe phát âm") { Speaker.say(word.term) }
        .accessibilityAction(named: "Nghe câu ví dụ") { Speaker.say(word.example) }
    }
}
