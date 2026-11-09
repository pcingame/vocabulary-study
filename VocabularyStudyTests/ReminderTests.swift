import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func triggersSkipTodayWhenStudied() {
    let t = Reminder.triggers(now: at(9), minutes: 20 * 60, studiedToday: true)
    #expect(t.count == Reminder.days - 1)
    #expect(cal.date(from: t[0]) == cal.date(bySettingHour: 20, minute: 0, second: 0, of: day(1)))
}

@Test func triggersSkipTodayWhenTimePassed() {
    let t = Reminder.triggers(now: at(21), minutes: 20 * 60, studiedToday: false)
    #expect(cal.date(from: t[0]) == cal.date(bySettingHour: 20, minute: 0, second: 0, of: day(1)))
}

@Test func triggersCountAndTime() {
    let t = Reminder.triggers(now: at(6), minutes: 7 * 60 + 30, studiedToday: false)
    #expect(t.count == Reminder.days)
    #expect(cal.date(from: t[0]) == cal.date(bySettingHour: 7, minute: 30, second: 0, of: day(0)))
    #expect(t.allSatisfy { $0.hour == 7 && $0.minute == 30 })
}
