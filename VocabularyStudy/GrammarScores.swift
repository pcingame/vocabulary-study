import Foundation

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
