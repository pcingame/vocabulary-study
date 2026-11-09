import SwiftUI
import SwiftData

@main
struct VocabularyStudyApp: App {
    private let container: ModelContainer
    @AppStorage(Settings.onboardedKey) private var onboarded = false
    @State private var today = Calendar.current.startOfDay(for: .now)

    init() {
        if LaunchFlags.uiTesting {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            UIView.setAnimationsEnabled(false)
            UserDefaults.standard.set(!LaunchFlags.showOnboarding, forKey: Settings.onboardedKey)
        }
        container = try! ModelContainer(for: Topic.self, Word.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: LaunchFlags.uiTesting))
        if LaunchFlags.seed { Self.seed(container.mainContext) }
        if LaunchFlags.seedLarge { Self.seedLarge(container.mainContext) }
        if LaunchFlags.stage1Done { Self.finishStage1(container.mainContext) }
        Content.sync((try? container.mainContext.fetch(FetchDescriptor<Topic>())) ?? [])
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Hôm nay", systemImage: "flame") { TodayView(today: today) }
                Tab("Chủ đề", systemImage: "books.vertical") { TopicsView() }
                Tab("Ngữ pháp", systemImage: "text.book.closed") { GrammarView() }
            }
            .fullScreenCover(isPresented: .constant(!onboarded)) { OnboardingView() }
            // Qua nửa đêm (kể cả lúc app đang ở nền) thì tạo lại query của tab Hôm nay.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                today = Calendar.current.startOfDay(for: .now)
            }
        }
        .modelContainer(container)
    }

    /// Chặng 1 đã xong: học hết bộ từ và đạt bài ngữ pháp (để test lộ trình).
    private static func finishStage1(_ context: ModelContext) {
        let stage = Roadmap.stages[0]
        Content.add(stage.deck, to: context)
        let topic = try! context.fetch(FetchDescriptor<Topic>()).first { $0.name == stage.deck.name }!
        for word in topic.words { word.answer(.easy) }
        var scores = GrammarScores()
        scores.record(stage.grammar, score: 8, of: 8)
        UserDefaults.standard.set(scores.rawValue, forKey: Settings.grammarScoresKey)
    }

    /// 50 chủ đề × 200 từ để đo hiệu năng. Tiến độ trộn đều: 1/3 chưa học, 1/3 đến hạn ôn, 1/3 chưa đến hạn.
    static func seedLarge(_ context: ModelContext, topics: Int = 50, perTopic: Int = 200, now: Date = .now) {
        for t in 0..<topics {
            let topic = Topic(name: "Lớn \(t + 1)")
            context.insert(topic)
            for i in 0..<perTopic {
                let w = Word(term: "word\(t)-\(i)", pos: "n", meaning: "nghĩa \(t)-\(i)",
                             createdAt: now.addingTimeInterval(Double(t * perTopic + i) - 1e6))
                if i % 3 != 0 {
                    w.learnedAt = now.addingTimeInterval(-86_400 * 30)
                    w.interval = i % 30 + 1
                    w.due = now.addingTimeInterval(86_400 * Double(i % 3 == 1 ? -(i % 7 + 1) : i % 20 + 1))
                }
                topic.words.append(w)
            }
        }
        try? context.save()
    }

    /// Dữ liệu mẫu cho UI test.
    private static func seed(_ context: ModelContext) {
        let topic = Topic(name: "Test")
        context.insert(topic)
        let words = [
            ("kind", "/kaɪnd/", "adj", "tử tế", "She is kind to everyone.", "Cô ấy tử tế với mọi người."),
            ("patient", "/ˈpeɪʃənt/", "adj", "kiên nhẫn", "Be patient with new staff.", "Hãy kiên nhẫn với nhân viên mới."),
            ("helpful", "/ˈhɛlpfəl/", "adj", "hay giúp đỡ", "The guide was very helpful.", "Hướng dẫn viên rất nhiệt tình giúp đỡ."),
        ]
        for (i, w) in words.enumerated() {
            topic.words.append(Word(term: w.0, ipa: w.1, pos: w.2, meaning: w.3, example: w.4, exampleMeaning: w.5,
                                    createdAt: Date(timeIntervalSince1970: Double(i))))
        }
    }
}

/// Cờ khởi động: `-ui-testing` = dữ liệu tạm trong bộ nhớ, không nhắc học; `-seed` = tạo chủ đề "Test"; `-show-onboarding` = hiện màn giới thiệu; `-stage1-done` = chặng 1 đã xong; `-seed-large` = 10.000 từ để đo hiệu năng.
enum LaunchFlags {
    static let uiTesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
    static let seed = ProcessInfo.processInfo.arguments.contains("-seed")
    static let showOnboarding = ProcessInfo.processInfo.arguments.contains("-show-onboarding")
    static let stage1Done = ProcessInfo.processInfo.arguments.contains("-stage1-done")
    static let seedLarge = ProcessInfo.processInfo.arguments.contains("-seed-large")
}
