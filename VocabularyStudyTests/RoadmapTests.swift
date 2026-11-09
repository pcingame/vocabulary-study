import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

@Test func roadmap() {
    #expect(Roadmap.stages.count == 10)
    #expect(Set(Roadmap.stages.map(\.deck.name)).count == 10)
    #expect(Set(Roadmap.stages.map(\.grammar.id)).count == 10)

    let topic = Roadmap.stages[0].grammar
    var scores = GrammarScores()
    scores.record(topic, score: 6, of: 8); #expect(!scores.passed(topic))
    #expect(Roadmap.current(topics: [], scores: scores)?.number == 1)  // chưa có từ vựng → vẫn ở chặng 1
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

@MainActor @Test func readdsOnlyCurrentStageWhenEnabled() throws {
    let container = try memoryContainer()
    let context = container.mainContext
    Roadmap.prepare(topics: [], scores: GrammarScores(), context: context, enabled: true)
    let stageTopic = try context.fetch(FetchDescriptor<Topic>())[0]
    let mine = Topic(name: "Của tôi")
    context.insert(mine)
    let topics = [stageTopic, mine]
    #expect(Roadmap.readdsAfterDelete(stageTopic, topics: topics, scores: GrammarScores(), enabled: true))
    #expect(!Roadmap.readdsAfterDelete(stageTopic, topics: topics, scores: GrammarScores(), enabled: false))
    #expect(!Roadmap.readdsAfterDelete(mine, topics: topics, scores: GrammarScores(), enabled: true))
}
