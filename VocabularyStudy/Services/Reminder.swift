import SwiftUI
import UserNotifications

enum Reminder {
    static let days = 60  // iOS cho tối đa 64 thông báo chờ

    /// Thời điểm nhắc cho `days` ngày tới. Bỏ hôm nay nếu đã học hoặc đã qua giờ nhắc.
    static func triggers(now: Date, minutes: Int, studiedToday: Bool, days: Int = days) -> [DateComponents] {
        let cal = Calendar.current
        return (0..<days).compactMap { offset in
            var when = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: offset, to: now)!)
            when.hour = minutes / 60
            when.minute = minutes % 60
            if offset == 0, studiedToday || cal.date(from: when)! <= now { return nil }
            return when
        }
    }

    /// Giờ nhắc (phút trong ngày) dạng Date cho DatePicker.
    static func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now)!
        } set: {
            let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
            minutes.wrappedValue = c.hour! * 60 + c.minute!
        }
    }

    /// Tiêu đề và nội dung lời nhắc. Hôm nay có số từ cần học thì ghi rõ số đó.
    static func message(isToday: Bool, isLast: Bool, dueToday: Int?) -> (title: String, body: String) {
        if isLast { return ("Lâu rồi chưa học 🥲", "Lâu rồi bạn chưa học, quay lại giữ chuỗi nhé!") }
        if isToday, let dueToday, dueToday > 0 { return ("Đến giờ học từ vựng 🔥", "Có \(dueToday) từ cần ôn hôm nay, vào học để giữ chuỗi nhé!") }
        return ("Đến giờ học từ vựng 🔥", "Ôn lại từ cũ và học từ mới để giữ chuỗi nhé!")
    }

    /// Đặt lại toàn bộ lịch nhắc. Gọi khi mở app, khi học xong và khi đổi giờ nhắc,
    /// nên chỉ cần thỉnh thoảng mở app là không bao giờ hết nhắc.
    /// `dueToday`: số thẻ còn phải học hôm nay, dùng cho badge và lời nhắc hôm nay (nil = giữ nguyên badge).
    static func schedule(dueToday: Int? = nil) async {
        guard !LaunchFlags.uiTesting else { return }
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        if let dueToday { try? await center.setBadgeCount(dueToday) }
        center.removeAllPendingNotificationRequests()
        let studiedToday = Streak.lastStudy.map { Calendar.current.isDateInToday($0) } ?? false
        let all = triggers(now: .now, minutes: Settings.reminderMinutes, studiedToday: studiedToday)
        // Gửi cả loạt song song, không chờ từng cái, để iOS không kịp treo app giữa chừng.
        await withTaskGroup { group in
            for (i, when) in all.enumerated() {
                let text = message(isToday: Calendar.current.date(from: when).map(Calendar.current.isDateInToday) ?? false,
                                   isLast: i == all.count - 1, dueToday: dueToday)
                group.addTask {
                    let content = UNMutableNotificationContent()
                    content.title = text.title
                    content.body = text.body
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
                    try? await UNUserNotificationCenter.current()
                        .add(UNNotificationRequest(identifier: "remind-\(i)", content: content, trigger: trigger))
                }
            }
        }
    }
}
