import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func matchesIgnoresCaseSpaceAccent() {
    #expect(Answer.matches(" Resume ", "résumé"))
    #expect(Answer.matches("in  charge   of", "in charge of"))
    #expect(!Answer.matches("kid", "kind"))
}

@Test func matchesRejectsPartial() {
    #expect(!Answer.matches("in charge", "in charge of"))
}

@Test func choicesContainAnswerAndAreUnique() {
    let words = ["a", "b", "c", "d", "e"].map { Word(term: $0, pos: "", meaning: "nghĩa \($0)") }
    let dup = Word(term: "f", pos: "", meaning: "Nghĩa A")  // trùng nghĩa với "a" (khác hoa thường)
    for _ in 0..<20 {
        let c = Answer.choices(for: words[0], pool: [dup] + words, fallback: [])!
        #expect(c.count == 4 && Set(c.map(Answer.normalize)).count == 4 && c.contains("nghĩa a"))
    }
}

@Test func choicesNilWhenPoolTooSmall() {
    let words = ["a", "b", "c"].map { Word(term: $0, pos: "", meaning: "nghĩa \($0)") }
    #expect(Answer.choices(for: words[0], pool: words, fallback: words) == nil)
    let extra = Word(term: "d", pos: "", meaning: "nghĩa d")
    #expect(Answer.choices(for: words[0], pool: words, fallback: [extra]) != nil)  // thiếu thì lấy thêm từ ngoài chủ đề
}
