import Foundation

enum Streak {
    /// Chuỗi sau khi học vào `now`.
    static func next(current: Int, last: Date?, freeze: Date? = lastFreeze, now: Date) -> Int {
        guard let last else { return 1 }
        let cal = Calendar.current
        if cal.isDate(last, inSameDayAs: now) { return current }
        if cal.isDate(last, inSameDayAs: cal.date(byAdding: .day, value: -1, to: now)!) { return current + 1 }
        return restDay(last: last, freeze: freeze, now: now) != nil ? current + 1 : 1
    }

    /// Chuỗi đang hiển thị: về 0 nếu đã bỏ lỡ hôm qua (trừ khi còn lượt nghỉ).
    static func display(current: Int, last: Date?, freeze: Date? = lastFreeze, now: Date = .now) -> Int {
        guard let last else { return 0 }
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let alive = cal.isDate(last, inSameDayAs: now) || cal.isDate(last, inSameDayAs: yesterday)
            || restDay(last: last, freeze: freeze, now: now) != nil
        return alive ? current : 0
    }

    /// Đóng băng chuỗi: chỉ lỡ đúng hôm qua, và 7 ngày trước đó chưa nghỉ lần nào → hôm qua là ngày nghỉ.
    static func restDay(last: Date, freeze: Date?, now: Date) -> Date? {
        let cal = Calendar.current
        let missed = cal.date(byAdding: .day, value: -1, to: now)!
        guard cal.isDate(last, inSameDayAs: cal.date(byAdding: .day, value: -2, to: now)!) else { return nil }
        if let freeze, cal.dateComponents([.day], from: cal.startOfDay(for: freeze), to: cal.startOfDay(for: missed)).day! < 7 {
            return nil
        }
        return missed
    }

    static var lastStudy: Date? { date(Settings.lastStudyKey) }
    static var lastFreeze: Date? { date(Settings.streakFreezeKey) }

    private static func date(_ key: String) -> Date? {
        let t = UserDefaults.standard.double(forKey: key)
        return t == 0 ? nil : Date(timeIntervalSince1970: t)
    }

    static func record(now: Date = .now) {
        if let last = lastStudy, Calendar.current.isDate(last, inSameDayAs: now) { return }
        let d = UserDefaults.standard
        let streak = next(current: d.integer(forKey: Settings.streakKey), last: lastStudy, now: now)  // tính trước khi ghi ngày nghỉ
        if let last = lastStudy, let rest = restDay(last: last, freeze: lastFreeze, now: now) {
            d.set(rest.timeIntervalSince1970, forKey: Settings.streakFreezeKey)
        }
        d.set(streak, forKey: Settings.streakKey)
        d.set(now.timeIntervalSince1970, forKey: Settings.lastStudyKey)
        Task { await Reminder.schedule() }
    }
}

/// Số thẻ đã học mỗi ngày, lưu trong UserDefaults dạng ["yyyy-MM-dd": số thẻ].
enum StudyLog {
    static let key = "studyLog"

    /// Ngày theo giờ máy (không dùng ISO8601 vì nó tính theo GMT, lệch ngày ở Việt Nam).
    static func day(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func increment(_ log: [String: Int], now: Date) -> [String: Int] {
        log.merging([day(now): 1], uniquingKeysWith: +)
    }

    static var counts: [String: Int] { UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:] }

    static func record(now: Date = .now) { UserDefaults.standard.set(increment(counts, now: now), forKey: key) }
}
