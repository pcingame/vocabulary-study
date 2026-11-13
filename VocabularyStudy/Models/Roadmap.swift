import Foundation
import SwiftData

struct Stage: Identifiable {
    let number: Int
    let deck: VocabDeck
    let grammar: GrammarTopic
    var id: Int { number }
    var title: String { deck.name.replacingOccurrences(of: "TOEIC · ", with: "") }
}

/// Lộ trình TOEIC: mỗi chặng = 1 chủ đề từ vựng + 1 bài ngữ pháp.
/// Xong chặng khi đã học hết từ và bài ngữ pháp đúng hết.
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
    static func prepare(topics: [Topic], scores: GrammarScores, context: ModelContext, enabled: Bool) {
        if enabled, let stage = current(topics: topics, scores: scores), topic(stage, in: topics) == nil {
            Content.add(stage.deck, to: context)
        }
    }

    /// Xoá chủ đề này thì `prepare` sẽ tự thêm lại (bộ từ của chặng hiện tại, lộ trình đang bật).
    static func readdsAfterDelete(_ topic: Topic, topics: [Topic], scores: GrammarScores, enabled: Bool) -> Bool {
        enabled && current(topics: topics, scores: scores)?.deck.name == topic.name
    }
}
