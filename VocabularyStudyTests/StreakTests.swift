import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func streak() {
    let usedFreeze = day(-3)  // vừa nghỉ cách đây vài ngày → hết lượt nghỉ
    #expect(Streak.next(current: 0, last: nil, freeze: nil, now: day(0)) == 1)
    #expect(Streak.next(current: 4, last: day(0), freeze: nil, now: day(0)) == 4)
    #expect(Streak.next(current: 4, last: day(-1), freeze: nil, now: day(0)) == 5)
    #expect(Streak.next(current: 4, last: day(-2), freeze: usedFreeze, now: day(0)) == 1)
    #expect(Streak.display(current: 4, last: day(-1), freeze: nil, now: day(0)) == 4)
    #expect(Streak.display(current: 4, last: day(-2), freeze: usedFreeze, now: day(0)) == 0)
}

@Test func streakFreeze() {
    // Lỡ đúng 1 ngày, chưa nghỉ lần nào → giữ chuỗi, hôm qua là ngày nghỉ.
    #expect(Streak.next(current: 4, last: day(-2), freeze: nil, now: day(0)) == 5)
    #expect(Streak.display(current: 4, last: day(-2), freeze: nil, now: day(0)) == 4)
    #expect(Streak.restDay(last: day(-2), freeze: nil, now: day(0)).map { cal.isDate($0, inSameDayAs: day(-1)) } == true)
    // Lỡ 2 ngày → mất chuỗi dù còn lượt.
    #expect(Streak.next(current: 4, last: day(-3), freeze: nil, now: day(0)) == 1)
    #expect(Streak.display(current: 4, last: day(-3), freeze: nil, now: day(0)) == 0)
    // Lần nghỉ trước cách ngày lỡ 6 ngày → chưa có lượt; 7 ngày → có lượt.
    #expect(Streak.next(current: 4, last: day(-2), freeze: day(-7), now: day(0)) == 1)
    #expect(Streak.next(current: 4, last: day(-2), freeze: day(-8), now: day(0)) == 5)
}

@Test func dailyLogIncrements() {
    var log: [String: Int] = [:]
    for _ in 0..<3 { log = StudyLog.increment(log, now: at(9)) }
    #expect(log[StudyLog.day(at(9))] == 3)
    log = StudyLog.increment(log, now: at(9).addingTimeInterval(86_400))
    #expect(log[StudyLog.day(at(9).addingTimeInterval(86_400))] == 1)
    #expect(StudyLog.day(at(23)) == StudyLog.day(at(0)))  // cùng ngày theo giờ máy
}
