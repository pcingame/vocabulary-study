import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var words: [Word]
    @Query private var topics: [Topic]
    @AppStorage("grammarScores") private var scores = GrammarScores()
    @AppStorage("streak") private var streak = 0
    @AppStorage("lastStudy") private var lastStudy = 0.0
    @AppStorage("reminderMinutes") private var reminderMinutes = Reminder.defaultMinutes
    @AppStorage(Settings.newPerDayKey) private var newPerDay = Settings.defaultNewPerDay
    @AppStorage(Settings.reviewPerDayKey) private var reviewPerDay = Settings.defaultReviewPerDay
    @AppStorage(Settings.roadmapAutoKey) private var roadmapAuto = true
    @State private var studying = false
    @State private var showingSettings = false

    var body: some View {
        let queue = Word.todayQueue(words, newLimit: newPerDay, reviewLimit: reviewPerDay)
        let newCount = queue.filter { $0.learnedAt == nil }.count
        NavigationStack {
            List {
                Section {
                    Label("\(Streak.display(current: streak, last: Streak.lastStudy)) ngày liên tiếp", systemImage: "flame.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.tint)
                }
                Section {
                    LabeledContent("Từ cần ôn", value: "\(queue.count - newCount)")
                    LabeledContent("Từ mới", value: "\(newCount)")
                    Button("Bắt đầu học") { studying = true }
                        .disabled(queue.isEmpty)
                        .accessibilityIdentifier("startStudy")
                } header: {
                    Text("Hôm nay")
                } footer: {
                    Text("Tổng cộng \(words.count) từ.")
                }
                RoadmapSection(topics: topics, scores: scores)
            }
            .navigationTitle("Hôm nay")
            .toolbar {
                Button("Cài đặt", systemImage: "gearshape") { showingSettings = true }
                    .accessibilityIdentifier("settingsButton")
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .fullScreenCover(isPresented: $studying) { StudyView(topic: nil) }
            .task(id: "\(reminderMinutes)-\(lastStudy)") { await Reminder.schedule() }
            .task(id: "\(Roadmap.current(topics: topics, scores: scores)?.number ?? 0)-\(roadmapAuto)") {
                Roadmap.prepare(topics: topics, scores: scores, context: context, enabled: roadmapAuto)
            }
        }
    }

}
