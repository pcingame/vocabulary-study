import SwiftData
import XCTest
@testable import VocabularyStudy

/// Đo thời gian lấy hàng đợi hôm nay với 10.000 từ (Swift Testing chưa có `measure`, nên dùng XCTest).
@MainActor final class PerformanceTests: XCTestCase {
    func testTodayQueueLarge() throws {
        let container = try ModelContainer(for: Topic.self, Word.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        VocabularyStudyApp.seedLarge(container.mainContext)
        measure {
            let context = ModelContext(container)  // context mới mỗi lần để không dùng lại object đã nạp
            let words = try! context.fetch(FetchDescriptor<Word>())
            XCTAssertEqual(Word.todayQueue(words, newLimit: 15, reviewLimit: 40).count, 55)
        }
    }
}
