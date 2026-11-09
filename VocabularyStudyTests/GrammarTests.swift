import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func passedWithEightQuestions() {
    let topic = Content.grammar[0]
    var scores = GrammarScores()
    scores.record(topic, score: 6, of: 8); #expect(!scores.passed(topic))
    scores.record(topic, score: 7, of: 8); #expect(scores.passed(topic))
    scores.record(topic, score: 2, of: 8); #expect(scores.passed(topic))  // giữ điểm cao nhất
    #expect(GrammarScores(rawValue: scores.rawValue)?.best == scores.best)
}

@Test func wrongAnswersTracked() {
    let topic = Content.grammar[0], q = topic.questions[2]
    var scores = GrammarScores()
    scores.answered(q, in: topic, correct: false)
    scores.answered(q, in: topic, correct: false)  // sai lại không bị nhân đôi
    #expect(scores.mistakes(topic) == [q])
    #expect(GrammarScores(rawValue: scores.rawValue)?.mistakes(topic) == [q])
    scores.answered(q, in: topic, correct: true)
    #expect(scores.mistakes(topic).isEmpty)
}
