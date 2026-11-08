import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

private let cal = Calendar.current
private func day(_ n: Int, from base: Date = cal.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 9))!) -> Date {
    cal.date(byAdding: .day, value: n, to: base)!
}

@Test func spacedRepetition() {
    let w = Word(term: "kind", pos: "adj", meaning: "tử tế")
    w.answer(remembered: true, now: day(0));  #expect(w.interval == 1)
    w.answer(remembered: true, now: day(1));  #expect(w.interval == 3)
    w.answer(remembered: true, now: day(4));  #expect(w.interval == 8)  // 3 × 2.5
    #expect(w.due == cal.startOfDay(for: day(12)))
    w.answer(remembered: false, now: day(12)); #expect(w.interval == 0 && w.due == day(12) && w.ease == 2.3)
}

@Test func dailyQueueLimitsNewWords() {
    let now = day(0)
    let words = (0..<30).map { Word(term: "w\($0)", pos: "", meaning: "", createdAt: day(-1).addingTimeInterval(Double($0))) }
    words[0].answer(remembered: true, now: now)   // từ mới đã học hôm nay
    words[1].answer(remembered: true, now: day(-5)) // đến hạn ôn
    let q = Word.todayQueue(words, newLimit: 15, reviewLimit: 40, now: now)
    #expect(q.first === words[1])
    #expect(q.count == 1 + (15 - 1))
    #expect(q[1] === words[2])  // từ mới theo thứ tự thêm vào
}

@Test func streak() {
    #expect(Streak.next(current: 0, last: nil, now: day(0)) == 1)
    #expect(Streak.next(current: 4, last: day(0), now: day(0)) == 4)
    #expect(Streak.next(current: 4, last: day(-1), now: day(0)) == 5)
    #expect(Streak.next(current: 4, last: day(-2), now: day(0)) == 1)
    #expect(Streak.display(current: 4, last: day(-1), now: day(0)) == 4)
    #expect(Streak.display(current: 4, last: day(-2), now: day(0)) == 0)
}

/// Dòng OCR thật từ ảnh sách trong `requirement/`.
@Test func parseBookPage() {
    let lines: [(text: String, x: Double)] = [
        ("Tính từ (Adjectives)", 0.26),
        ("generous / dseneras/ (adj) - hào phóng", 0.24),
        ("kind-hearted/, katnd ha:rtd/", 0.23),
        ("(adj) - tốt bụng", 0.23),
        ("understanding /, andar 'staendy", 0.56),
        ("compassionate/kam pa/anat/", 0.23),
        ("(adj) - nhân ái, trắc ẩn", 0.23),
        ("(ad]) - thấu hiều", 0.56),
        ("fair /fcr/ (adi) công bằng", 0.55),
        ("sincere Istn str (ad))", 0.19),
        ("LÒNG TỐT", 0.23),
    ]
    #expect(OCR.parse(lines) == [
        Draft(term: "generous", pos: "adj", meaning: "hào phóng"),
        Draft(term: "kind-hearted", pos: "adj", meaning: "tốt bụng"),
        Draft(term: "understanding", pos: "adj", meaning: "thấu hiều"),
        Draft(term: "compassionate", pos: "adj", meaning: "nhân ái, trắc ẩn"),
        Draft(term: "fair", pos: "adj", meaning: "công bằng"),
    ])
}

@Test func bundledContentIsValid() {
    #expect(Content.vocab.count == 10)
    for deck in Content.vocab {
        for w in deck.words {
            #expect(w.count == 6 && w[0...5].allSatisfy { !$0.isEmpty }, "\(deck.name): \(w)")
            #expect(w[1].hasPrefix("/") && w[1].hasSuffix("/"), "phiên âm: \(w)")
            #expect(w[4].lowercased().contains(w[0].lowercased().prefix(4)), "ví dụ không chứa từ: \(w)")
        }
    }
    #expect(Set(Content.grammar.map(\.id)).count == Content.grammar.count)
    for topic in Content.grammar {
        #expect(!topic.questions.isEmpty)
        for q in topic.questions { #expect(q.options.count == 4 && q.options.indices.contains(q.answer), "\(q.q)") }
    }
}

@Test func roadmap() {
    #expect(Roadmap.stages.count == 10)
    #expect(Set(Roadmap.stages.map(\.deck.name)).count == 10)
    #expect(Set(Roadmap.stages.map(\.grammar.id)).count == 10)

    let topic = Roadmap.stages[0].grammar  // 6 câu: đạt khi đúng ≥ 5
    var scores = GrammarScores()
    scores.best[topic.id] = 4; #expect(!scores.passed(topic))
    scores.best[topic.id] = 5; #expect(scores.passed(topic))
    #expect(Roadmap.current(topics: [], scores: scores)?.number == 1)  // chưa có từ vựng → vẫn ở chặng 1
}

@Test func editKeepsSchedule() {
    let w = Word(term: "kind", pos: "adj", meaning: "tử tế")
    w.answer(remembered: true, now: day(0))
    w.answer(remembered: true, now: day(1))
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

@Test func dailyQueueRespectsCustomLimits() {
    let now = day(0)
    let due = (0..<30).map { i -> Word in
        let w = Word(term: "d\(i)", pos: "", meaning: "")
        w.answer(remembered: true, now: day(-5))  // đến hạn từ day(-4)
        return w
    }
    let fresh = (0..<30).map { Word(term: "n\($0)", pos: "", meaning: "") }
    let q = Word.todayQueue(due + fresh, newLimit: 5, reviewLimit: 10, now: now)
    #expect(q.filter { $0.learnedAt != nil }.count == 10)
    #expect(q.filter { $0.learnedAt == nil }.count == 5)
}

@MainActor @Test func roadmapPrepareRespectsToggle() throws {
    let container = try ModelContainer(for: Topic.self, Word.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    Roadmap.prepare(topics: [], scores: GrammarScores(), context: context, enabled: false)
    #expect(try context.fetch(FetchDescriptor<Topic>()).isEmpty)
    Roadmap.prepare(topics: [], scores: GrammarScores(), context: context, enabled: true)
    let topics = try context.fetch(FetchDescriptor<Topic>())
    #expect(topics.count == 1 && topics[0].words.count == 20)
}

/// Container in-memory; phải giữ biến container còn sống trong suốt test, context không tự giữ container.
@MainActor private func memoryContainer() throws -> ModelContainer {
    try ModelContainer(for: Topic.self, Word.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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

private func at(_ hour: Int) -> Date { cal.date(bySettingHour: hour, minute: 0, second: 0, of: day(0))! }

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
