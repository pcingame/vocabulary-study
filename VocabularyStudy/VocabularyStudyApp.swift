import SwiftUI
import SwiftData

@main
struct VocabularyStudyApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Hôm nay", systemImage: "flame") { TodayView() }
                Tab("Chủ đề", systemImage: "books.vertical") { TopicsView() }
            }
        }
        .modelContainer(for: [Topic.self, Word.self])
    }
}
