import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    // Chỉ nạp những từ cần cho hôm nay (fetch theo mức trần, cắt theo cài đặt ở dưới), không nạp cả bảng.
    @Query private var reviews: [Word]
    @Query private var fresh: [Word]
    @Query private var learnedToday: [Word]
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingSettings = false

    init(today: Date = Calendar.current.startOfDay(for: .now)) {
        _reviews = Query(Word.dueReviews(today: today, limit: Settings.maxReviewPerDay))
        _fresh = Query(Word.unlearned(limit: Settings.maxNewPerDay))
        _learnedToday = Query(Word.learnedSince(today))
    }

    var body: some View {
        let queue = Array(reviews.prefix(reviewPerDay)) + Array(fresh.prefix(max(0, newPerDay - learnedToday.count)))
        let newCount = queue.filter { $0.learnedAt == nil }.count
        let days = Streak.display(current: streak, last: Streak.lastStudy)
        let done = StudyLog.counts[StudyLog.day(.now)] ?? 0
        NavigationStack {
            List {
                Section {
                    // Chữ rất to thì xếp dọc để "ngày liên tiếp" không bị bẻ từng chữ.
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                                              : AnyLayout(HStackLayout())
                    layout {
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
                        Spacer(minLength: 0)
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
                        VStack(spacing: 2) {
                            Label("Bắt đầu học", systemImage: "play.fill").font(.headline)
                            Text(mode.title).font(.caption)
                        }
                        .fixedSize(horizontal: false, vertical: true)  // chữ to thì nút cao lên, không cắt chữ
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))  // hình viên thuốc cắt mép khi chữ nhiều dòng
                    .controlSize(.large)
                    .disabled(queue.isEmpty)
                    .accessibilityIdentifier("startStudy")
                } header: {
                    Text("Hôm nay")
                } footer: {
                    Text("Tổng cộng \((try? context.fetchCount(FetchDescriptor<Word>())) ?? 0) từ.")
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
            .lineLimit(1)
            .minimumScaleFactor(0.4)  // vòng có giới hạn kích thước, chữ to thì thu nhỏ cho vừa
            .padding(14)
        }
        .frame(width: min(size, 130), height: min(size, 130))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hôm nay đã học \(done) trên \(total) thẻ")
        .accessibilityIdentifier("todayProgress")
    }
}
