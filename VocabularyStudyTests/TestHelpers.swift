import Foundation
import SwiftData
@testable import VocabularyStudy

let cal = Calendar.current

func day(_ n: Int, from base: Date = cal.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 9))!) -> Date {
    cal.date(byAdding: .day, value: n, to: base)!
}

func at(_ hour: Int) -> Date { cal.date(bySettingHour: hour, minute: 0, second: 0, of: day(0))! }

/// Container in-memory; phải giữ biến container còn sống trong suốt test, context không tự giữ container.
@MainActor func memoryContainer() throws -> ModelContainer {
    try ModelContainer(for: Topic.self, Word.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}
