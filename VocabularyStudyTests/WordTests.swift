import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func editKeepsSchedule() {
    let w = Word(term: "kind", pos: "adj", meaning: "tử tế")
    w.answer(.easy, now: day(0))
    w.answer(.easy, now: day(1))
    let learned = w.learnedAt, due = w.due
    var fields = WordFields(w)
    fields.meaning = "  tốt bụng "
    fields.apply(to: w)
    #expect(w.meaning == "tốt bụng")
    #expect(w.interval == 3 && w.learnedAt == learned && w.due == due)
}

@Test func wordFieldsValidation() {
    var f = WordFields()
    #expect(!f.isValid)
    f.term = "   "; f.meaning = "x"
    #expect(!f.isValid)
    f.term = "kind"
    #expect(f.isValid && f.makeWord().term == "kind")
}

@Test func searchMatchesMeaningWithoutAccents() {
    let words = [Word(term: "generous", pos: "adj", meaning: "hào phóng"),
                 Word(term: "deadline", pos: "n", meaning: "hạn chót"),
                 Word(term: "budget", pos: "n", meaning: "ngân sách, dự toán")]
    #expect(Word.search(words, query: "hao phong", status: nil).map(\.term) == ["generous"])
    #expect(Word.search(words, query: "du toan", status: nil).map(\.term) == ["budget"])  // đ = d
    #expect(Word.search(words, query: "DEAD", status: nil).map(\.term) == ["deadline"])
    words[1].answer(.easy, now: day(0))
    #expect(Word.search(words, query: "", status: .learning).map(\.term) == ["deadline"])
    #expect(Word.search(words, query: "", status: .new).map(\.term) == ["budget", "generous"])
}

@Test func rejectsDuplicateTopicName() {
    let topics = [Topic(name: "Sách")]
    #expect(Topic.nameTaken("sách ", in: topics))
    #expect(Topic.nameTaken("SÁCH", in: topics))
    #expect(!Topic.nameTaken("Sach", in: topics))  // khác dấu là tên khác
    #expect(!Topic.nameTaken("Sách 2", in: topics))
}
