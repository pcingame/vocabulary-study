import SwiftUI
import SwiftData

struct VocabDeck: Decodable {
    let name: String
    let words: [[String]]  // [từ, phiên âm, từ loại, nghĩa, câu ví dụ, nghĩa câu ví dụ]
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
            topic.words.append(Word(term: w[0], ipa: w[1], pos: w[2], meaning: w[3], example: w[4], exampleMeaning: w[5],
                                    createdAt: now.addingTimeInterval(Double(i) / 1000)))
        }
    }

    /// Điền IPA / câu ví dụ / nghĩa câu ví dụ còn trống cho bộ từ TOEIC đã thêm từ bản cũ.
    /// Chỉ đụng tới chủ đề trùng tên bộ có sẵn, và không ghi đè ô người dùng đã điền.
    static func sync(_ topics: [Topic]) {
        for deck in vocab {
            guard let topic = topics.first(where: { $0.name == deck.name }) else { continue }
            let rows = Dictionary(deck.words.map { ($0[0], $0) }, uniquingKeysWith: { first, _ in first })
            for word in topic.words {
                guard let row = rows[word.term] else { continue }
                if word.ipa.isEmpty { word.ipa = row[1] }
                if word.example.isEmpty { word.example = row[4] }
                if word.exampleMeaning.isEmpty { word.exampleMeaning = row[5] }
            }
        }
    }

    private static func load<T: Decodable>(_ name: String) -> T {
        let url = Bundle.main.url(forResource: name, withExtension: "json")!
        return try! JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}

/// Điểm cao nhất (%) và các câu làm sai của mỗi bài ngữ pháp, lưu chung một key để mọi màn hình cùng cập nhật.
struct GrammarScores: RawRepresentable {
    var best: [String: Int] = [:]        // id bài → % đúng cao nhất
    var wrong: [String: [String]] = [:]  // id bài → đề các câu đang sai

    static let quizSize = 8

    // Struct riêng để encode: nếu cho GrammarScores tự Codable thì Swift sẽ encode qua rawValue → lặp vô hạn.
    private struct Stored: Codable { var best: [String: Int]; var wrong: [String: [String]] }

    init() {}
    init?(rawValue: String) {
        guard let s = try? JSONDecoder().decode(Stored.self, from: Data(rawValue.utf8)) else { return }
        best = s.best; wrong = s.wrong
    }
    var rawValue: String { String(decoding: try! JSONEncoder().encode(Stored(best: best, wrong: wrong)), as: UTF8.self) }

    /// Đạt khi đúng từ 80% trở lên.
    func passed(_ topic: GrammarTopic) -> Bool { (best[topic.id] ?? 0) >= 80 }

    mutating func record(_ topic: GrammarTopic, score: Int, of total: Int) {
        best[topic.id] = max(best[topic.id] ?? 0, score * 100 / max(1, total))
    }

    /// Sai thì thêm vào danh sách ôn, đúng thì bỏ ra.
    mutating func answered(_ q: Question, in topic: GrammarTopic, correct: Bool) {
        var list = wrong[topic.id, default: []].filter { $0 != q.q }
        if !correct { list.append(q.q) }
        wrong[topic.id] = list.isEmpty ? nil : list
    }

    func mistakes(_ topic: GrammarTopic) -> [Question] {
        let list = Set(wrong[topic.id] ?? [])
        return topic.questions.filter { list.contains($0.q) }
    }
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
            Label("\(best)%", systemImage: scores.passed(topic) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(scores.passed(topic) ? .green : .secondary)
        }
    }
}

struct GrammarLessonView: View {
    let topic: GrammarTopic
    @AppStorage("grammarScores") private var scores = GrammarScores()
    @State private var quiz: QuizKind?

    enum QuizKind: Identifiable { case random, mistakes; var id: Self { self } }

    var body: some View {
        ScrollView {
            Text((try? AttributedString(markdown: topic.lesson,
                                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                 ?? AttributedString(topic.lesson))
                .frame(maxWidth: .infinity, alignment: .leading)
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
        }
        .navigationTitle(topic.name)
        .fullScreenCover(item: $quiz) { QuizView(topic: topic, reviewing: $0 == .mistakes) }
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
    @AppStorage("grammarScores") private var scores = GrammarScores()

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
                    question(questions[index])
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
                        picked = i
                        if i == q.answer { score += 1 }
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
