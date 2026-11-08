import SwiftUI
import SwiftData

@main
struct VocabularyStudyApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Hôm nay", systemImage: "flame") { TodayView() }
                Tab("Chủ đề", systemImage: "books.vertical") { TopicsView() }
                Tab("Ngữ pháp", systemImage: "text.book.closed") { GrammarView() }
            }
        }
        .modelContainer(for: [Topic.self, Word.self])
    }
}
