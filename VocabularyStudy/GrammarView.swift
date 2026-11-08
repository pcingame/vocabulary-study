import SwiftUI
import SwiftData

struct VocabDeck: Decodable {
    let name: String
    let words: [[String]]  // [từ, từ loại, nghĩa, câu ví dụ, nghĩa câu ví dụ]
}

struct GrammarTopic: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let lesson: String
    let questions: [Question]
}

struct Question: Decodable, Hashable {
    let q: String
    let options: [String]
    let answer: Int
    let explain: String
}

/// Nội dung TOEIC đóng gói sẵn trong app (Resources/*.json).
enum Content {
    static let vocab: [VocabDeck] = load("toeic_vocab")
    static let grammar: [GrammarTopic] = load("toeic_grammar")

    static func add(_ deck: VocabDeck, to context: ModelContext) {
        let topic = Topic(name: deck.name)
        context.insert(topic)
        let now = Date.now
        for (i, w) in deck.words.enumerated() {
            topic.words.append(Word(term: w[0], pos: w[1], meaning: w[2], example: w[3], exampleMeaning: w[4],
                                    createdAt: now.addingTimeInterval(Double(i) / 1000)))
        }
    }

    private static func load<T: Decodable>(_ name: String) -> T {
        let url = Bundle.main.url(forResource: name, withExtension: "json")!
        return try! JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}

/// Điểm cao nhất mỗi bài ngữ pháp, lưu chung một key để mọi màn hình cùng cập nhật.
struct GrammarScores: RawRepresentable {
    var best: [String: Int] = [:]

    init() {}
    init?(rawValue: String) { best = (try? JSONDecoder().decode([String: Int].self, from: Data(rawValue.utf8))) ?? [:] }
    var rawValue: String { String(decoding: try! JSONEncoder().encode(best), as: UTF8.self) }

    /// Đạt khi đúng từ 80% trở lên.
    func passed(_ topic: GrammarTopic) -> Bool { (best[topic.id] ?? 0) * 5 >= topic.questions.count * 4 }
}

struct GrammarView: View {
    var body: some View {
        NavigationStack {
            List(Content.grammar) { topic in
                NavigationLink(value: topic) {
                    LabeledContent(topic.name) { BestScore(topic: topic) }
                }
            }
            .navigationTitle("Ngữ pháp TOEIC")
            .navigationDestination(for: GrammarTopic.self) { GrammarLessonView(topic: $0) }
        }
    }
}

struct BestScore: View {
    let topic: GrammarTopic
    @AppStorage("grammarScores") private var scores = GrammarScores()

    var body: some View {
        if let best = scores.best[topic.id] {
            Label("\(best)/\(topic.questions.count)", systemImage: scores.passed(topic) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(scores.passed(topic) ? .green : .secondary)
        }
    }
}

struct GrammarLessonView: View {
    let topic: GrammarTopic
    @State private var quizzing = false

    var body: some View {
        ScrollView {
            Text((try? AttributedString(markdown: topic.lesson,
                                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                 ?? AttributedString(topic.lesson))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button { quizzing = true } label: {
                Text("Làm \(topic.questions.count) câu bài tập").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .navigationTitle(topic.name)
        .fullScreenCover(isPresented: $quizzing) { QuizView(topic: topic) }
    }
}

struct QuizView: View {
    let topic: GrammarTopic
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var picked: Int?
    @State private var score = 0
    @AppStorage("grammarScores") private var scores = GrammarScores()

    private var count: Int { topic.questions.count }

    var body: some View {
        NavigationStack {
            Group {
                if index < count {
                    question(topic.questions[index])
                } else {
                    ContentUnavailableView {
                        Label("\(score)/\(count) câu đúng", systemImage: score == count ? "star.fill" : "checkmark.seal")
                    } actions: {
                        Button("Làm lại") { index = 0; score = 0 }
                    }
                }
            }
            .navigationTitle(index < count ? "Câu \(index + 1)/\(count)" : topic.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Đóng") { dismiss() } }
        }
    }

    private func question(_ q: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(q.q).font(.title3).padding(.bottom)
                ForEach(q.options.indices, id: \.self) { i in
                    Button {
                        guard picked == nil else { return }
                        picked = i
                        if i == q.answer { score += 1 }
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
                    }
                    .buttonStyle(.plain)
                }
                if picked != nil {
                    Text(q.explain).foregroundStyle(.secondary).padding(.vertical)
                    Button {
                        picked = nil
                        index += 1
                        if index == count { scores.best[topic.id] = max(scores.best[topic.id] ?? 0, score) }
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
