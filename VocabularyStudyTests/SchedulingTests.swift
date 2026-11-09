import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func spacedRepetition() {
    let w = Word(term: "kind", pos: "adj", meaning: "tử tế")
    w.answer(.easy, now: day(0));  #expect(w.interval == 1)
    w.answer(.easy, now: day(1));  #expect(w.interval == 3)
    w.answer(.easy, now: day(4));  #expect(w.interval == 8)  // 3 × 2.5
    #expect(w.due == cal.startOfDay(for: day(12)))
    w.answer(.forgot, now: day(12)); #expect(w.interval == 0 && w.due == day(12) && w.ease == 2.6)  // 2.5 + 3×0.1 − 0.2
}

@Test func dailyQueueLimitsNewWords() {
    let now = day(0)
    let words = (0..<30).map { Word(term: "w\($0)", pos: "", meaning: "", createdAt: day(-1).addingTimeInterval(Double($0))) }
    words[0].answer(.easy, now: now)   // từ mới đã học hôm nay
    words[1].answer(.easy, now: day(-5)) // đến hạn ôn
    let q = Word.todayQueue(words, newLimit: 15, reviewLimit: 40, now: now)
    #expect(q.first === words[1])
    #expect(q.count == 1 + (15 - 1))
    #expect(q[1] === words[2])  // từ mới theo thứ tự thêm vào
}

@Test func dailyQueueRespectsCustomLimits() {
    let now = day(0)
    let due = (0..<30).map { i -> Word in
        let w = Word(term: "d\(i)", pos: "", meaning: "")
        w.answer(.easy, now: day(-5))  // đến hạn từ day(-4)
        return w
    }
    let fresh = (0..<30).map { Word(term: "n\($0)", pos: "", meaning: "") }
    let q = Word.todayQueue(due + fresh, newLimit: 5, reviewLimit: 10, now: now)
    #expect(q.filter { $0.learnedAt != nil }.count == 10)
    #expect(q.filter { $0.learnedAt == nil }.count == 5)
}

@Test func gradeHard() {
    let w = Word(term: "kind", pos: "adj", meaning: "tử tế")
    w.answer(.easy, now: day(0)); #expect(w.interval == 1)
    w.answer(.easy, now: day(1)); #expect(w.interval == 3)
    w.answer(.hard, now: day(4)); #expect(w.interval == 4)  // 3 × 1.2 làm tròn
    #expect(w.due == cal.startOfDay(for: day(8)))
}

@Test func gradeEaseBounds() {
    let w = Word(term: "kind", pos: "adj", meaning: "tử tế")
    var rng = SystemRandomNumberGenerator()
    for i in 0..<50 {
        w.answer([.forgot, .hard, .easy].randomElement(using: &rng)!, now: day(i))
        #expect((1.3...3.0).contains(w.ease))
    }
    for i in 0..<20 { w.answer(.easy, now: day(50 + i)) }
    #expect(w.ease == 3.0)
}

@Test func wordStatusThresholds() {
    let w = Word(term: "kind", pos: "adj", meaning: "tử tế")
    #expect(w.status == .new)
    w.answer(.easy, now: day(0))
    w.interval = 20; #expect(w.status == .learning)
    w.interval = 21; #expect(w.status == .mastered)
}

@Test func dueCountToday() {
    #expect(Reminder.message(isToday: true, isLast: false, dueToday: 12).body.contains("Có 12 từ cần ôn"))
    #expect(!Reminder.message(isToday: false, isLast: false, dueToday: 12).body.contains("12"))  // ngày sau: câu chung
    #expect(!Reminder.message(isToday: true, isLast: false, dueToday: 0).body.contains("Có 0"))
    #expect(Reminder.message(isToday: false, isLast: true, dueToday: nil).title.contains("Lâu rồi"))
}

@MainActor @Test func fetchedQueueMatchesFiltered() throws {
    let container = try memoryContainer()
    let context = container.mainContext
    let now = Date.now
    VocabularyStudyApp.seedLarge(context, topics: 3, perTopic: 60, now: now)
    let words = try context.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.createdAt)]))
    words[0].answer(.easy, now: now)    // từ mới học hôm nay (chưa lưu), chiếm 1 suất
    words[3].answer(.forgot, now: now)  // từ mới quên lúc nãy, đến hạn ngay
    words[5].answer(.forgot, now: now)  // từ cũ quên
    for (n, r) in [(15, 40), (5, 10), (1, 100)] {
        let old = Word.todayQueue(words, newLimit: n, reviewLimit: r, now: now)
        let new = Word.todayQueue(in: context, newLimit: n, reviewLimit: r, now: now)
        #expect(old.map(\.term) == new.map(\.term))
    }
}
