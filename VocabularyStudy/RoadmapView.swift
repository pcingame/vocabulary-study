import SwiftUI
import SwiftData

struct Stage: Identifiable {
    let number: Int
    let deck: VocabDeck
    let grammar: GrammarTopic
    var id: Int { number }
    var title: String { deck.name.replacingOccurrences(of: "TOEIC · ", with: "") }
}

/// Lộ trình TOEIC: mỗi chặng = 1 chủ đề từ vựng + 1 bài ngữ pháp.
/// Xong chặng khi đã học hết từ và bài ngữ pháp đạt từ 80%.
enum Roadmap {
    // Đi từ chủ đề quen thuộc + ngữ pháp nền tảng tới chủ đề khó + ngữ pháp nâng cao.
    static let stages: [Stage] = [
        ("TOEIC · Văn phòng", "word-forms"),
        ("TOEIC · Nhân sự & Tuyển dụng", "pronouns"),
        ("TOEIC · Họp & Giao tiếp", "tenses"),
        ("TOEIC · Du lịch & Công tác", "prepositions"),
        ("TOEIC · Nhà hàng & Sự kiện", "passive"),
        ("TOEIC · Mua sắm & Đặt hàng", "conjunctions"),
        ("TOEIC · Marketing & Bán hàng", "comparisons"),
        ("TOEIC · Tài chính & Ngân hàng", "gerunds-infinitives"),
        ("TOEIC · Sản xuất & Kho vận", "relative-clauses"),
        ("TOEIC · Hợp đồng", "conditionals"),
    ].enumerated().map { i, pair in
        Stage(number: i + 1,
              deck: Content.vocab.first { $0.name == pair.0 }!,
              grammar: Content.grammar.first { $0.id == pair.1 }!)
    }

    static func topic(_ stage: Stage, in topics: [Topic]) -> Topic? {
        topics.first { $0.name == stage.deck.name }
    }

    static func vocabProgress(_ stage: Stage, topics: [Topic]) -> (learned: Int, total: Int) {
        guard let words = topic(stage, in: topics)?.words else { return (0, stage.deck.words.count) }
        return (words.filter { $0.learnedAt != nil }.count, words.count)
    }

    static func isDone(_ stage: Stage, topics: [Topic], scores: GrammarScores) -> Bool {
        let p = vocabProgress(stage, topics: topics)
        return topic(stage, in: topics) != nil && p.learned >= p.total && scores.passed(stage.grammar)
    }

    /// Chặng đang học; nil khi đã xong cả lộ trình.
    static func current(topics: [Topic], scores: GrammarScores) -> Stage? {
        stages.first { !isDone($0, topics: topics, scores: scores) }
    }

    /// Tự thêm bộ từ của chặng hiện tại vào lịch học, để mỗi ngày chỉ cần bấm "Bắt đầu học".
    static func prepare(topics: [Topic], scores: GrammarScores, context: ModelContext) {
        if let stage = current(topics: topics, scores: scores), topic(stage, in: topics) == nil {
            Content.add(stage.deck, to: context)
        }
    }
}

/// Ô lộ trình trên tab Hôm nay.
struct RoadmapSection: View {
    let topics: [Topic]
    let scores: GrammarScores

    var body: some View {
        Section("Lộ trình TOEIC") {
            if let stage = Roadmap.current(topics: topics, scores: scores) {
                let p = Roadmap.vocabProgress(stage, topics: topics)
                let passed = scores.passed(stage.grammar)
                NavigationLink { RoadmapView() } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Chặng \(stage.number)/\(Roadmap.stages.count): \(stage.title)").font(.headline)
                        ProgressView(value: Double(p.learned + (passed ? p.total : 0)), total: Double(max(1, p.total * 2)))
                        Text("Từ vựng \(p.learned)/\(p.total) · Ngữ pháp: \(passed ? "đạt" : "chưa đạt")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !passed {
                    NavigationLink { GrammarLessonView(topic: stage.grammar) } label: {
                        Label("Bài ngữ pháp: \(stage.grammar.name)", systemImage: "text.book.closed")
                    }
                }
            } else {
                NavigationLink { RoadmapView() } label: {
                    Label("Đã hoàn thành lộ trình! 🎉", systemImage: "trophy.fill")
                }
            }
        }
    }
}

struct RoadmapView: View {
    @Query private var topics: [Topic]
    @AppStorage("grammarScores") private var scores = GrammarScores()

    var body: some View {
        let current = Roadmap.current(topics: topics, scores: scores)?.number ?? .max
        List {
            Section {
                Text("Mỗi chặng gồm 1 chủ đề từ vựng và 1 bài ngữ pháp. Học hết từ của chặng (mỗi ngày tối đa \(Word.newPerDay) từ mới, app tự xếp lịch ôn) và làm bài ngữ pháp đạt từ 80% để mở chặng tiếp theo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(Roadmap.stages) { stage in
                let p = Roadmap.vocabProgress(stage, topics: topics)
                Section {
                    if let topic = Roadmap.topic(stage, in: topics) {
                        NavigationLink { TopicDetailView(topic: topic) } label: {
                            LabeledContent("Từ vựng: \(stage.title)", value: "\(p.learned)/\(p.total)")
                        }
                    } else {
                        LabeledContent("Từ vựng: \(stage.title)", value: "\(p.total) từ")
                    }
                    NavigationLink { GrammarLessonView(topic: stage.grammar) } label: {
                        LabeledContent("Ngữ pháp: \(stage.grammar.name)") { BestScore(topic: stage.grammar) }
                    }
                } header: {
                    Label("Chặng \(stage.number)",
                          systemImage: stage.number < current ? "checkmark.circle.fill"
                                     : stage.number == current ? "play.circle.fill" : "lock.fill")
                }
                .disabled(stage.number > current)
            }
        }
        .navigationTitle("Lộ trình TOEIC")
    }
}
