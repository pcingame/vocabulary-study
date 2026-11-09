import Foundation
import SwiftData

struct VocabDeck: Decodable {
    struct Entry: Decodable {
        let term, ipa, pos, meaning, example, exampleMeaning: String
    }
    let name: String
    let words: [Entry]
}

struct GrammarTopic: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let lesson: [LessonBlock]
    let questions: [Question]
}

/// Một khối bài giảng: đoạn chữ (có **đậm**), công thức (khung màu) hoặc câu ví dụ (có nghĩa, chạm để nghe).
struct LessonBlock: Decodable, Hashable {
    enum Kind: String, Decodable { case text, formula, example }
    let type: Kind
    let text: String
    var meaning: String?
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
            topic.words.append(Word(term: w.term, ipa: w.ipa, pos: w.pos, meaning: w.meaning, example: w.example, exampleMeaning: w.exampleMeaning,
                                    createdAt: now.addingTimeInterval(Double(i) / 1000)))
        }
    }

    /// Điền IPA / câu ví dụ / nghĩa câu ví dụ còn trống cho bộ từ TOEIC đã thêm từ bản cũ.
    /// Chỉ đụng tới chủ đề trùng tên bộ có sẵn, và không ghi đè ô người dùng đã điền.
    static func sync(_ topics: [Topic]) {
        for deck in vocab {
            guard let topic = topics.first(where: { $0.name == deck.name }) else { continue }
            let rows = Dictionary(deck.words.map { ($0.term, $0) }, uniquingKeysWith: { first, _ in first })
            for word in topic.words {
                guard let row = rows[word.term] else { continue }
                if word.ipa.isEmpty { word.ipa = row.ipa }
                if word.example.isEmpty { word.example = row.example }
                if word.exampleMeaning.isEmpty { word.exampleMeaning = row.exampleMeaning }
            }
        }
    }

    private static func load<T: Decodable>(_ name: String) -> T {
        let url = Bundle.main.url(forResource: name, withExtension: "json")!
        return try! JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
