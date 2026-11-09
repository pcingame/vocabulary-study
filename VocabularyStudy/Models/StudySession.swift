import Foundation

/// Hàng đợi một buổi học. Từ trả lời Quên được đưa xuống cuối để học lại trong buổi.
struct StudySession {
    var queue: [Word] = []
    private(set) var summary = SessionSummary()
    private(set) var answered = 0  // làm id thẻ để reset ô nhập, kể cả khi gặp lại đúng từ vừa quên

    mutating func answer(_ grade: Word.Grade) {
        let word = queue.removeFirst()
        word.answer(grade)
        summary.add(word, grade)
        if grade == .forgot { queue.append(word) }
        answered += 1
    }
}

/// Kết quả một buổi học. Mỗi từ tính theo lần trả lời đầu tiên; từ quên nhiều lần chỉ ghi 1 lần.
struct SessionSummary {
    private var first: [ObjectIdentifier: Word.Grade] = [:]
    private(set) var forgotten: [Word] = []

    mutating func add(_ word: Word, _ grade: Word.Grade) {
        let id = ObjectIdentifier(word)
        if first[id] == nil { first[id] = grade }
        if grade == .forgot && !forgotten.contains(where: { $0 === word }) { forgotten.append(word) }
    }

    var wordCount: Int { first.count }
    func count(_ grade: Word.Grade) -> Int { first.values.filter { $0 == grade }.count }

    static let milestones = [7, 30, 100]
}
