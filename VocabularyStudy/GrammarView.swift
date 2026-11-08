import SwiftUI

struct VocabDeck: Decodable {
    let name: String
    let words: [[String]]  // [từ, từ loại, nghĩa]
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

    private static func load<T: Decodable>(_ name: String) -> T {
        let url = Bundle.main.url(forResource: name, withExtension: "json")!
        return try! JSONDecoder().decode(T.self, from: Data(contentsOf: url))
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

private struct BestScore: View {
    let topic: GrammarTopic
    @AppStorage private var best: Int

    init(topic: GrammarTopic) {
        self.topic = topic
        _best = AppStorage(wrappedValue: -1, "grammar-\(topic.id)")
    }

    var body: some View {
        if best >= 0 { Text("\(best)/\(topic.questions.count)") }
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
    @AppStorage private var best: Int

    init(topic: GrammarTopic) {
        self.topic = topic
        _best = AppStorage(wrappedValue: -1, "grammar-\(topic.id)")
    }

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
                        if index == count { best = max(best, score) }
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
