import SwiftUI
import SwiftData
import UserNotifications

@Model final class Topic {
    var name: String
    var createdAt = Date.now
    @Relationship(deleteRule: .cascade, inverse: \Word.topic) var words: [Word] = []

    init(name: String) { self.name = name }

    /// Tên đã có (không phân biệt hoa thường, bỏ khoảng trắng hai đầu).
    static func nameTaken(_ name: String, in topics: [Topic]) -> Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        return topics.contains { $0.name.compare(n, options: .caseInsensitive) == .orderedSame }
    }
}

@Model final class Word {
    #Index<Word>([\.due], [\.learnedAt])  // cho fetch hàng đợi hôm nay

    var term: String
    var ipa = ""
    var pos: String
    var meaning: String
    var example = ""
    var exampleMeaning = ""
    var topic: Topic?
    var createdAt = Date.now
    var learnedAt: Date?   // nil = chưa học
    var due = Date.now
    var interval = 0       // số ngày tới lần ôn sau
    var ease = 2.5

    init(term: String, ipa: String = "", pos: String, meaning: String, example: String = "", exampleMeaning: String = "",
         createdAt: Date = .now) {
        self.term = term
        self.ipa = ipa
        self.pos = pos
        self.meaning = meaning
        self.example = example
        self.exampleMeaning = exampleMeaning
        self.createdAt = createdAt
    }

    enum Grade { case forgot, hard, easy }

    enum Status: CaseIterable { case new, learning, mastered }

    /// Mới: chưa học. Đang học: ôn cách nhau dưới 21 ngày. Đã thuộc: từ 21 ngày.
    var status: Status { learnedAt == nil ? .new : interval < 21 ? .learning : .mastered }

    /// Lặp lại ngắt quãng (SM-2 rút gọn).
    /// Dễ: 1 → 3 → × ease ngày, ease +0.1. Khó: × 1.2 (ít nhất 1 ngày), ease −0.15. Quên: học lại ngay, ease −0.2.
    func answer(_ grade: Grade, now: Date = .now) {
        if learnedAt == nil { learnedAt = now }
        switch grade {
        case .forgot:
            interval = 0
            ease = max(1.3, ease - 0.2)
        case .hard:
            interval = max(1, Int((Double(interval) * 1.2).rounded()))
            ease = max(1.3, ease - 0.15)
        case .easy:
            interval = interval == 0 ? 1 : interval == 1 ? 3 : Int((Double(interval) * ease).rounded())
            ease = min(3.0, ease + 0.1)
        }
        due = grade == .forgot ? now
            : Calendar.current.date(byAdding: .day, value: interval, to: Calendar.current.startOfDay(for: now))!
    }

    /// Tìm theo từ hoặc nghĩa (không cần gõ dấu), lọc theo trạng thái nếu có.
    static func search(_ words: [Word], query: String, status: Status?) -> [Word] {
        let q = Answer.normalize(query)
        return words.filter { w in
            (status == nil || w.status == status)
                && (q.isEmpty || Answer.normalize(w.term).contains(q) || Answer.normalize(w.meaning).contains(q))
        }
        .sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
    }

    /// Từ cần ôn (tối đa `reviewLimit`) + từ mới (tối đa `newLimit`/ngày, tính cả từ mới đã học trong ngày).
    static func todayQueue(_ words: [Word], newLimit: Int = Settings.newPerDay, reviewLimit: Int = Settings.reviewPerDay,
                           now: Date = .now) -> [Word] {
        let today = Calendar.current.startOfDay(for: now)
        let newToday = words.filter { ($0.learnedAt ?? .distantPast) >= today }.count
        let reviews = words.filter { $0.learnedAt != nil && $0.due <= now }.sorted { ($0.due, $0.createdAt) < ($1.due, $1.createdAt) }
        let fresh = words.filter { $0.learnedAt == nil }.sorted { $0.createdAt < $1.createdAt }
        return Array(reviews.prefix(reviewLimit)) + Array(fresh.prefix(max(0, newLimit - newToday)))
    }

    // Bản fetch có điều kiện của `todayQueue`, cho toàn bộ từ (nhiều từ thì lọc trong bộ nhớ chậm).
    // Hạn ôn luôn là đầu một ngày, hoặc lúc bấm Quên, nên "due < đầu ngày mai" giống "due <= now"
    // và không bị cũ khi view giữ nguyên query cả ngày.

    /// Từ đến hạn ôn, hạn sớm nhất trước (cùng hạn thì từ thêm trước lên trước).
    static func dueReviews(today: Date, limit: Int) -> FetchDescriptor<Word> {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        var d = FetchDescriptor<Word>(predicate: #Predicate { $0.learnedAt != nil && $0.due < tomorrow }, sortBy: [SortDescriptor(\.due), SortDescriptor(\.createdAt)])
        d.fetchLimit = limit
        return d
    }

    /// Từ chưa học, theo thứ tự thêm vào.
    static func unlearned(limit: Int) -> FetchDescriptor<Word> {
        var d = FetchDescriptor<Word>(predicate: #Predicate { $0.learnedAt == nil }, sortBy: [SortDescriptor(\.createdAt)])
        d.fetchLimit = limit
        return d
    }

    /// Từ mới đã học từ đầu ngày `today`.
    static func learnedSince(_ today: Date) -> FetchDescriptor<Word> {
        FetchDescriptor(predicate: #Predicate { w in if let d = w.learnedAt { d >= today } else { false } })
    }

    static func todayQueue(in context: ModelContext, newLimit: Int = Settings.newPerDay, reviewLimit: Int = Settings.reviewPerDay,
                           now: Date = .now) -> [Word] {
        // Fetch có fetchLimit cắt trên dữ liệu đã lưu rồi mới bỏ từ vừa đổi, nên lưu trước để không thiếu thẻ.
        if context.hasChanges { try? context.save() }
        let today = Calendar.current.startOfDay(for: now)
        let remaining = newLimit - ((try? context.fetchCount(learnedSince(today))) ?? 0)
        let reviews = (try? context.fetch(dueReviews(today: today, limit: reviewLimit))) ?? []
        // fetchLimit 0 nghĩa là không giới hạn, nên hết suất từ mới thì không fetch.
        return reviews + (remaining > 0 ? (try? context.fetch(unlearned(limit: remaining))) ?? [] : [])
    }
}

/// Nội dung người dùng nhập cho một từ. Sửa nội dung không đụng tới tiến độ ôn.
struct WordFields: Equatable {
    var term = "", ipa = "", pos = "", meaning = "", example = "", exampleMeaning = ""

    init() {}
    init(_ w: Word) {
        (term, ipa, pos, meaning, example, exampleMeaning) = (w.term, w.ipa, w.pos, w.meaning, w.example, w.exampleMeaning)
    }

    var isValid: Bool { !trimmed(term).isEmpty && !trimmed(meaning).isEmpty }

    func apply(to w: Word) {
        (w.term, w.ipa, w.pos, w.meaning, w.example, w.exampleMeaning) =
            (trimmed(term), trimmed(ipa), trimmed(pos), trimmed(meaning), trimmed(example), trimmed(exampleMeaning))
    }

    func makeWord() -> Word {
        let w = Word(term: "", pos: "", meaning: "")
        apply(to: w)
        return w
    }

    private func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
}
