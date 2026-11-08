import Foundation
import SwiftData
import UserNotifications

@Model final class Topic {
    var name: String
    var createdAt = Date.now
    @Relationship(deleteRule: .cascade, inverse: \Word.topic) var words: [Word] = []

    init(name: String) { self.name = name }
}

@Model final class Word {
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

    /// Lặp lại ngắt quãng (SM-2 rút gọn): nhớ → 1, 3, rồi nhân `ease` ngày; quên → học lại ngay.
    func answer(remembered: Bool, now: Date = .now) {
        if learnedAt == nil { learnedAt = now }
        if remembered {
            interval = interval == 0 ? 1 : interval == 1 ? 3 : Int((Double(interval) * ease).rounded())
            due = Calendar.current.date(byAdding: .day, value: interval, to: Calendar.current.startOfDay(for: now))!
        } else {
            interval = 0
            ease = max(1.3, ease - 0.2)
            due = now
        }
    }

    /// Từ cần ôn (tối đa `reviewLimit`) + từ mới (tối đa `newLimit`/ngày, tính cả từ mới đã học trong ngày).
    static func todayQueue(_ words: [Word], newLimit: Int = Settings.newPerDay, reviewLimit: Int = Settings.reviewPerDay,
                           now: Date = .now) -> [Word] {
        let today = Calendar.current.startOfDay(for: now)
        let newToday = words.filter { ($0.learnedAt ?? .distantPast) >= today }.count
        let reviews = words.filter { $0.learnedAt != nil && $0.due <= now }.sorted { $0.due < $1.due }
        let fresh = words.filter { $0.learnedAt == nil }.sorted { $0.createdAt < $1.createdAt }
        return Array(reviews.prefix(reviewLimit)) + Array(fresh.prefix(max(0, newLimit - newToday)))
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

enum Streak {
    /// Chuỗi sau khi học vào `now`.
    static func next(current: Int, last: Date?, now: Date) -> Int {
        guard let last else { return 1 }
        let cal = Calendar.current
        if cal.isDate(last, inSameDayAs: now) { return current }
        if cal.isDate(last, inSameDayAs: cal.date(byAdding: .day, value: -1, to: now)!) { return current + 1 }
        return 1
    }

    /// Chuỗi đang hiển thị: về 0 nếu đã bỏ lỡ hôm qua.
    static func display(current: Int, last: Date?, now: Date = .now) -> Int {
        guard let last else { return 0 }
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        return cal.isDate(last, inSameDayAs: now) || cal.isDate(last, inSameDayAs: yesterday) ? current : 0
    }

    static var lastStudy: Date? {
        let t = UserDefaults.standard.double(forKey: "lastStudy")
        return t == 0 ? nil : Date(timeIntervalSince1970: t)
    }

    static func record(now: Date = .now) {
        if let last = lastStudy, Calendar.current.isDate(last, inSameDayAs: now) { return }
        let d = UserDefaults.standard
        d.set(next(current: d.integer(forKey: "streak"), last: lastStudy, now: now), forKey: "streak")
        d.set(now.timeIntervalSince1970, forKey: "lastStudy")
        Task { await Reminder.schedule() }
    }
}

enum Reminder {
    static let defaultMinutes = 20 * 60

    /// Lên lịch nhắc cho 30 ngày tới, bỏ qua hôm nay nếu đã học.
    // ponytail: lịch 30 ngày đặt lại mỗi lần mở app; không mở app 30 ngày thì hết nhắc.
    static func schedule() async {
        guard !LaunchFlags.uiTesting else { return }
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
        center.removeAllPendingNotificationRequests()
        let minutes = UserDefaults.standard.object(forKey: "reminderMinutes") as? Int ?? defaultMinutes
        let studiedToday = Streak.lastStudy.map { Calendar.current.isDateInToday($0) } ?? false
        let content = UNMutableNotificationContent()
        content.title = "Đến giờ học từ vựng 🔥"
        content.body = "Ôn lại từ cũ và học từ mới để giữ chuỗi nhé!"
        content.sound = .default
        for offset in (studiedToday ? 1 : 0)..<30 {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: .now)!
            var when = Calendar.current.dateComponents([.year, .month, .day], from: day)
            when.hour = minutes / 60
            when.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "remind-\(offset)", content: content, trigger: trigger))
        }
    }
}
