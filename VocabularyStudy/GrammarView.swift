import SwiftUI

struct GrammarView: View {
    var body: some View {
        NavigationStack {
            List(Content.grammar) { topic in
                NavigationLink(value: topic) {
                    LabeledContent(topic.name) { BestScore(topic: topic) }
                }
                .accessibilityLabel(topic.name)  // không có dòng này VoiceOver đọc trống khi chưa có điểm
            }
            .navigationTitle("Ngữ pháp TOEIC")
            .navigationDestination(for: GrammarTopic.self) { GrammarLessonView(topic: $0) }
        }
    }
}

struct BestScore: View {
    let topic: GrammarTopic
    @AppStorage(Settings.grammarScoresKey) private var scores = GrammarScores()

    var body: some View {
        if let best = scores.best[topic.id] {
            Label("\(best)%", systemImage: scores.passed(topic) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(scores.passed(topic) ? .green : .secondary)
        }
    }
}

struct GrammarLessonView: View {
    let topic: GrammarTopic
    @AppStorage(Settings.grammarScoresKey) private var scores = GrammarScores()
    @State private var quiz: QuizKind?

    enum QuizKind: Identifiable { case random, mistakes; var id: Self { self } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(topic.lesson, id: \.self) { LessonBlockView(block: $0) }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                let wrong = scores.mistakes(topic).count
                if wrong > 0 {
                    Button { quiz = .mistakes } label: { Text("Ôn \(wrong) câu sai").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("reviewMistakes")
                }
                Button { quiz = .random } label: {
                    Text("Làm \(min(GrammarScores.quizSize, topic.questions.count)) câu bài tập").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("startQuiz")
            }
            .controlSize(.large)
            .padding()
            .background(.bar)  // nền đặc, không để chữ bài giảng hiện xuyên qua nút
        }
        .navigationTitle(topic.name)
        .fullScreenCover(item: $quiz) { QuizView(topic: topic, reviewing: $0 == .mistakes) }
    }
}

struct LessonBlockView: View {
    let block: LessonBlock

    var body: some View {
        switch block.type {
        case .text:
            Text((try? AttributedString(markdown: block.text)) ?? AttributedString(block.text))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .formula:
            Text(block.text)
                .font(.callout.weight(.semibold).monospaced())
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.tint.opacity(0.12), in: .rect(cornerRadius: 10))
                .overlay(alignment: .leading) { Rectangle().fill(.tint).frame(width: 4) }
                .clipShape(.rect(cornerRadius: 10))
        case .example:
            Button { Speaker.say(block.text) } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.text).italic()
                        if let meaning = block.meaning { Text(meaning).font(.callout).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Chạm để nghe")
        }
    }
}

/// Làm bài: ngẫu nhiên 8 câu (tính điểm), hoặc ôn các câu đang sai (không tính điểm).
struct QuizView: View {
    let topic: GrammarTopic
    let reviewing: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var picked: Int?
    @State private var score = 0
    @State private var shakes = 0  // tăng mỗi lần chọn sai để chạy hiệu ứng rung
    @AppStorage(Settings.grammarScoresKey) private var scores = GrammarScores()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var count: Int { questions.count }

    private func start() {
        questions = reviewing ? scores.mistakes(topic) : Array(topic.questions.shuffled().prefix(GrammarScores.quizSize))
        index = 0; score = 0; picked = nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if questions.isEmpty {
                    Color.clear  // chờ start() trong onAppear
                } else if index < count {
                    VStack(spacing: 0) {
                        ProgressView(value: Double(index + (picked == nil ? 0 : 1)), total: Double(count))
                            .padding(.horizontal)
                            .animation(reduceMotion ? nil : .spring, value: picked)
                        question(questions[index]).id(index)  // view mới cho mỗi câu, không mang theo hiệu ứng của câu trước
                    }
                } else {
                    ContentUnavailableView {
                        Label("\(score)/\(count) câu đúng", systemImage: score == count ? "star.fill" : "checkmark.seal")
                    } actions: {
                        if !reviewing { Button("Làm lại") { start() } }
                    }
                }
            }
            .navigationTitle(index < count ? "Câu \(index + 1)/\(count)" : topic.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Đóng") { dismiss() } }
            .onAppear { if questions.isEmpty { start() } }
        }
    }

    private func question(_ q: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(q.q).font(.title3).padding(.bottom)
                ForEach(q.options.indices, id: \.self) { i in
                    Button {
                        guard picked == nil else { return }
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { picked = i }
                        if i == q.answer { score += 1 } else { shakes += 1 }
                        scores.answered(q, in: topic, correct: i == q.answer)
                    } label: {
                        HStack {
                            Text("\(String(UnicodeScalar(UInt8(65 + i)))). \(q.options[i])")
                            Spacer()
                            if picked != nil && i == q.answer {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if picked == i {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(background(i, q), in: .rect(cornerRadius: 12))
                        .contentShape(.rect)
                        // Đúng: sáng lên. Sai: rung lắc. Reduce Motion: chỉ đổi màu.
                        .scaleEffect(!reduceMotion && picked != nil && i == q.answer ? 1.03 : 1)
                        .shadow(color: .green.opacity(!reduceMotion && picked != nil && i == q.answer ? 0.5 : 0), radius: 8)
                        .keyframeAnimator(initialValue: 0.0, trigger: picked == i && i != q.answer && !reduceMotion ? shakes : 0) {
                            $0.offset(x: $1)
                        } keyframes: { _ in
                            KeyframeTrack {
                                for x in [-10.0, 9, -7, 5, -3, 0] { CubicKeyframe(x, duration: 0.06) }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if picked != nil {
                    Text(q.explain).foregroundStyle(.secondary).padding(.vertical)
                    Button {
                        picked = nil
                        index += 1
                        if index == count && !reviewing { scores.record(topic, score: score, of: count) }
                    } label: {
                        Text(index + 1 < count ? "Câu tiếp" : "Xem kết quả").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
    }

    private func background(_ i: Int, _ q: Question) -> Color {
        guard picked != nil else { return .secondary.opacity(0.12) }
        if i == q.answer { return .green.opacity(0.25) }
        if i == picked { return .red.opacity(0.25) }
        return .secondary.opacity(0.12)
    }
}
