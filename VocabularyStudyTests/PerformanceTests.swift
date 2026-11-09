import SwiftData
import XCTest
@testable import VocabularyStudy

/// Đo thời gian lấy hàng đợi hôm nay với 10.000 từ (Swift Testing chưa có `measure`, nên dùng XCTest).
@MainActor final class PerformanceTests: XCTestCase {
    private func largeContainer() throws -> ModelContainer {
        let container = try ModelContainer(for: Topic.self, Word.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        VocabularyStudyApp.seedLarge(container.mainContext)
        return container
    }

    /// Mốc cũ: nạp hết rồi lọc trong bộ nhớ (~0,18 s).
    func testTodayQueueFilterAll() throws {
        let container = try largeContainer()
        measure {
            let words = try! ModelContext(container).fetch(FetchDescriptor<Word>())  // context mới để không dùng lại object đã nạp
            XCTAssertEqual(Word.todayQueue(words, newLimit: 15, reviewLimit: 40).count, 55)
        }
    }

    /// Fetch có điều kiện (~0,003 s).
    func testTodayQueueFetched() throws {
        let container = try largeContainer()
        measure {
            XCTAssertEqual(Word.todayQueue(in: ModelContext(container), newLimit: 15, reviewLimit: 40).count, 55)
        }
    }
}
