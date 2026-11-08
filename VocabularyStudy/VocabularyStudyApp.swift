import SwiftUI
import SwiftData

@main
struct VocabularyStudyApp: App {
    private let container: ModelContainer
    @AppStorage("onboarded") private var onboarded = false

    init() {
        if LaunchFlags.uiTesting {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            UIView.setAnimationsEnabled(false)
            UserDefaults.standard.set(!LaunchFlags.showOnboarding, forKey: "onboarded")
        }
        container = try! ModelContainer(for: Topic.self, Word.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: LaunchFlags.uiTesting))
        if LaunchFlags.seed { Self.seed(container.mainContext) }
        Content.sync((try? container.mainContext.fetch(FetchDescriptor<Topic>())) ?? [])
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Hôm nay", systemImage: "flame") { TodayView() }
                Tab("Chủ đề", systemImage: "books.vertical") { TopicsView() }
                Tab("Ngữ pháp", systemImage: "text.book.closed") { GrammarView() }
            }
            .fullScreenCover(isPresented: .constant(!onboarded)) { OnboardingView() }
        }
        .modelContainer(container)
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

/// Cờ khởi động: `-ui-testing` = dữ liệu tạm trong bộ nhớ, không nhắc học; `-seed` = tạo chủ đề "Test"; `-show-onboarding` = hiện màn giới thiệu.
enum LaunchFlags {
    static let uiTesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
    static let seed = ProcessInfo.processInfo.arguments.contains("-seed")
    static let showOnboarding = ProcessInfo.processInfo.arguments.contains("-show-onboarding")
}
