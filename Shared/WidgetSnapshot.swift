import Foundation

/// Số liệu app gửi cho widget qua App Group: chuỗi ngày và số thẻ cần học, cho hôm nay và ngày mai.
struct WidgetSnapshot: Codable, Equatable {
    struct Day: Codable, Equatable {
        var start: Date   // đầu ngày
        var streak: Int
        var due: Int      // số thẻ còn phải học trong ngày
    }
    var days: [Day]

    static let group = "group.com.doanthanhphuong.VocabularyStudy"
    static let key = "widgetSnapshot"

    /// Ngày mới nhất đã bắt đầu tính tới `now`. Quá ngày mai mà chưa mở app thì vẫn dùng số của ngày mai.
    func day(at now: Date) -> Day? { days.last { $0.start <= now } }

    static func load() -> WidgetSnapshot? {
        UserDefaults(suiteName: group)?.data(forKey: key).flatMap { try? JSONDecoder().decode(Self.self, from: $0) }
    }

    func save() {
        UserDefaults(suiteName: Self.group)?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
