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
    @AppStorage("studyMode") private var mode = StudyMode.flip
    @State private var studying = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false

    var body: some View {
        let queue = Word.todayQueue(words, newLimit: newPerDay, reviewLimit: reviewPerDay)
        let newCount = queue.filter { $0.learnedAt == nil }.count
        let days = Streak.display(current: streak, last: Streak.lastStudy)
        let done = StudyLog.counts[StudyLog.day(.now)] ?? 0
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.tint)
                                .symbolEffect(.bounce, value: reduceMotion ? 0 : days)
                            Text("\(days)").font(.largeTitle.bold()).contentTransition(.numericText())
                            Text("ngày liên tiếp").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(days) ngày liên tiếp")
                        .accessibilityIdentifier("streak")
                        Spacer()
                        ProgressRing(done: done, total: done + queue.count)
                    }
                    .padding(.vertical, 8)
                    .animation(reduceMotion ? nil : .spring, value: done)
                }
                Section {
                    LabeledContent("Từ cần ôn") { Text("\(queue.count - newCount)").contentTransition(.numericText()) }
                    LabeledContent("Từ mới") { Text("\(newCount)").contentTransition(.numericText()) }
                    Picker("Cách học", selection: $mode) {
                        ForEach(StudyMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("studyModePicker")
                    Button { studying = true } label: {
                        Label("Bắt đầu học · \(mode.title)", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
                NavigationLink { StatsView() } label: { Label("Thống kê", systemImage: "chart.bar") }
                    .accessibilityIdentifier("statsButton")
                Button("Cài đặt", systemImage: "gearshape") { showingSettings = true }
                    .accessibilityIdentifier("settingsButton")
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .fullScreenCover(isPresented: $studying) { StudyView(topic: nil) }
            .task(id: "\(reminderMinutes)-\(lastStudy)-\(queue.count)") { await Reminder.schedule(dueToday: queue.count) }
            .task(id: "\(Roadmap.current(topics: topics, scores: scores)?.number ?? 0)-\(roadmapAuto)") {
                Roadmap.prepare(topics: topics, scores: scores, context: context, enabled: roadmapAuto)
            }
        }
    }

}

/// Vòng tiến độ học hôm nay: đã học / tổng thẻ.
struct ProgressRing: View {
    let done: Int
    let total: Int
    @ScaledMetric private var size = 92.0  // to theo cỡ chữ để số không bị chật

    var body: some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: total == 0 ? 0 : Double(done) / Double(total))
                .stroke(.tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(done)/\(total)").font(.headline).monospacedDigit().contentTransition(.numericText())
                Text("thẻ").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hôm nay đã học \(done) trên \(total) thẻ")
        .accessibilityIdentifier("todayProgress")
    }
}
