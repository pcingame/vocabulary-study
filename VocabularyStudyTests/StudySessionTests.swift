import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func swipeDecision() {
    #expect(StudyView.swipeDecision(120) == .easy)
    #expect(StudyView.swipeDecision(-120) == .forgot)
    #expect(StudyView.swipeDecision(60) == nil && StudyView.swipeDecision(-60) == nil)
}

@Test func summaryCountsForgottenOnce() {
    let a = Word(term: "a", pos: "", meaning: ""), b = Word(term: "b", pos: "", meaning: "")
    var s = SessionSummary()
    s.add(a, .forgot); s.add(b, .easy); s.add(a, .forgot); s.add(a, .easy)
    #expect(s.wordCount == 2 && s.forgotten.count == 1 && s.forgotten[0] === a)
    #expect(s.count(.forgot) == 1 && s.count(.easy) == 1 && s.count(.hard) == 0)  // theo lần trả lời đầu
}

@Test func sessionRequeuesForgotten() {
    let a = Word(term: "a", pos: "", meaning: ""), b = Word(term: "b", pos: "", meaning: "")
    var s = StudySession(queue: [a, b])
    s.answer(.forgot)  // a quên → xuống cuối
    #expect(s.queue.map(\.term) == ["b", "a"])
    s.answer(.easy); s.answer(.forgot); s.answer(.easy)  // a quên lần 2 rồi nhớ
    #expect(s.queue.isEmpty && s.answered == 4)
    #expect(s.summary.wordCount == 2 && s.summary.forgotten.count == 1)
}

@Test func practiceKeepsSchedule() {
    let a = Word(term: "a", pos: "", meaning: "")
    a.answer(.easy)
    let (interval, due, learned) = (a.interval, a.due, a.learnedAt)
    var s = StudySession.practice([a])
    #expect(s.practice)
    s.answer(.forgot); s.answer(.easy)  // quên vẫn xếp lại cuối hàng, nhưng không đổi lịch ôn
    #expect(s.queue.isEmpty && s.summary.words.count == 1)
    #expect(a.interval == interval && a.due == due && a.learnedAt == learned)
}

@Test func practiceRotatesModes() {
    let words = (0..<5).map { Word(term: "\($0)", pos: "", meaning: "") }
    var normal = StudySession(queue: words)
    normal.answer(.easy)
    #expect(normal.mode(default: .choice) == .choice)  // học thường: theo Cài đặt
    var s = StudySession.practice(words)
    var modes: [StudyMode] = []
    while !s.queue.isEmpty { modes.append(s.mode(default: .choice)); s.answer(.easy) }
    #expect(modes == [.flip, .typing, .listening, .choice, .flip])
}
