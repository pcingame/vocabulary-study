import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func bundledContentIsValid() {
    #expect(Content.vocab.count == 20)
    for deck in Content.vocab {
        for w in deck.words {
            #expect([w.term, w.ipa, w.pos, w.meaning, w.example, w.exampleMeaning].allSatisfy { !$0.isEmpty }, "\(deck.name): \(w)")
            #expect(w.ipa.hasPrefix("/") && w.ipa.hasSuffix("/"), "phiên âm: \(w)")
            #expect(w.example.lowercased().contains(w.term.lowercased().prefix(4)), "ví dụ không chứa từ: \(w)")
        }
    }
    #expect(Set(Content.grammar.map(\.id)).count == Content.grammar.count)
    for topic in Content.grammar {
        #expect(topic.questions.count >= 15, "\(topic.id)")
        #expect(topic.lesson.contains { $0.type == .formula } && topic.lesson.contains { $0.type == .example }, "\(topic.id)")
        for block in topic.lesson {
            #expect(!block.text.isEmpty, "\(topic.id)")
            #expect((block.type == .example) == (block.meaning != nil), "chỉ ví dụ mới có nghĩa: \(block.text)")
        }
        #expect(Set(topic.questions.map(\.q)).count == topic.questions.count, "trùng đề: \(topic.id)")
        for q in topic.questions { #expect(q.options.count == 4 && q.options.indices.contains(q.answer), "\(q.q)") }
    }
}

@MainActor @Test func syncFillsMissingFields() throws {
    let container = try memoryContainer()
    let context = container.mainContext
    let topic = Topic(name: "TOEIC · Văn phòng")
    context.insert(topic)
    topic.words.append(Word(term: "agenda", pos: "n", meaning: "chương trình nghị sự"))
    Content.sync([topic])
    #expect(topic.words[0].ipa == "/əˈdʒɛndə/")
    #expect(topic.words[0].example.contains("agenda") && !topic.words[0].exampleMeaning.isEmpty)
}

@MainActor @Test func syncKeepsUserEdits() throws {
    let container = try memoryContainer()
    let context = container.mainContext
    let topic = Topic(name: "TOEIC · Văn phòng")
    context.insert(topic)
    topic.words.append(Word(term: "agenda", pos: "n", meaning: "x", exampleMeaning: "abc"))
    Content.sync([topic])
    #expect(topic.words[0].exampleMeaning == "abc")
    #expect(topic.words[0].ipa == "/əˈdʒɛndə/")
}

@MainActor @Test func syncIgnoresUserTopics() throws {
    let container = try memoryContainer()
    let context = container.mainContext
    let topic = Topic(name: "Từ của tôi")
    context.insert(topic)
    topic.words.append(Word(term: "agenda", pos: "n", meaning: "x"))
    Content.sync([topic])
    #expect(topic.words[0].ipa.isEmpty && topic.words[0].example.isEmpty)
}
