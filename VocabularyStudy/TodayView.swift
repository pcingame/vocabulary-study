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
    @State private var studying = false

    var body: some View {
        let queue = Word.todayQueue(words)
        let newCount = queue.filter { $0.learnedAt == nil }.count
        NavigationStack {
            List {
                Section {
                    Label("\(Streak.display(current: streak, last: Streak.lastStudy)) ngày liên tiếp", systemImage: "flame.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                }
                Section("Hôm nay") {
                    LabeledContent("Từ cần ôn", value: "\(queue.count - newCount)")
                    LabeledContent("Từ mới", value: "\(newCount)")
                    Button("Bắt đầu học") { studying = true }
                        .disabled(queue.isEmpty)
                }
                RoadmapSection(topics: topics, scores: scores)
                Section {
                    DatePicker("Giờ nhắc học", selection: reminderTime, displayedComponents: .hourAndMinute)
                } footer: {
                    Text("Tổng cộng \(words.count) từ.")
                }
            }
            .navigationTitle("Hôm nay")
            .fullScreenCover(isPresented: $studying) { StudyView(topic: nil) }
            .task(id: "\(reminderMinutes)-\(lastStudy)") { await Reminder.schedule() }
            .task(id: Roadmap.current(topics: topics, scores: scores)?.number) {
                Roadmap.prepare(topics: topics, scores: scores, context: context)
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now)!
        } set: {
            let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
            reminderMinutes = c.hour! * 60 + c.minute!
        }
    }
}
