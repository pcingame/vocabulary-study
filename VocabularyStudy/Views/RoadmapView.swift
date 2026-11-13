import SwiftUI
import SwiftData

/// Ô lộ trình trên tab Hôm nay.
struct RoadmapSection: View {
    let stage: Stage?  // chặng đang học, nil = xong lộ trình
    let topics: [Topic]
    let scores: GrammarScores

    var body: some View {
        Section("Lộ trình TOEIC") {
            if let stage {
                let p = Roadmap.vocabProgress(stage, topics: topics)
                let passed = scores.passed(stage.grammar)
                NavigationLink { RoadmapView() } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Chặng \(stage.number)/\(Roadmap.stages.count): \(stage.title)").font(.headline)
                        ProgressView(value: Double(p.learned + (passed ? p.total : 0)), total: Double(max(1, p.total * 2)))
                        Text("Từ vựng \(p.learned)/\(p.total) · Ngữ pháp: \(passed ? "đạt" : "chưa đạt")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !passed {
                    NavigationLink { GrammarLessonView(topic: stage.grammar) } label: {
                        Label("Bài ngữ pháp: \(stage.grammar.name)", systemImage: "text.book.closed")
                    }
                }
            } else {
                NavigationLink { RoadmapView() } label: {
                    Label("Đã hoàn thành lộ trình! 🎉", systemImage: "trophy.fill")
                }
            }
        }
    }
}

struct RoadmapView: View {
    @Query private var topics: [Topic]
    @AppStorage(Settings.grammarScoresKey) private var scores = GrammarScores()
    @AppStorage(Settings.lastSeenStageKey) private var lastSeenStage = 1
    @State private var unlocked: Int?  // chặng vừa mở khoá, để chạy animation 1 lần

    var body: some View {
        let current = Roadmap.current(topics: topics, scores: scores)?.number ?? Roadmap.stages.count + 1
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Mỗi chặng gồm 1 chủ đề từ vựng và 1 bài ngữ pháp. Học hết từ của chặng (mỗi ngày tối đa \(Settings.newPerDay) từ mới, app tự xếp lịch ôn) và làm bài ngữ pháp đúng hết để mở chặng tiếp theo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
                ForEach(Roadmap.stages) { stage in
                    let state: StageNode.State = stage.number < current ? .done : stage.number == current ? .current : .locked
                    NavigationLink { StageDetailView(stage: stage) } label: {
                        StageRow(stage: stage, state: state, isLast: stage.number == Roadmap.stages.count,
                                 justUnlocked: unlocked == stage.number,
                                 progress: Roadmap.vocabProgress(stage, topics: topics), passed: scores.passed(stage.grammar))
                    }
                    .buttonStyle(.plain)
                    .disabled(state == .locked)
                }
            }
            .padding()
        }
        .navigationTitle("Lộ trình TOEIC")
        .onAppear {
            if current > lastSeenStage, current <= Roadmap.stages.count { unlocked = current }
            lastSeenStage = max(lastSeenStage, current)
        }
    }
}

/// Một chặng trên timeline: nút tròn + đường nối xuống chặng sau, bên phải là tên và tiến độ.
struct StageRow: View {
    let stage: Stage
    let state: StageNode.State
    let isLast: Bool
    let justUnlocked: Bool
    let progress: (learned: Int, total: Int)
    let passed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                StageNode(state: state, justUnlocked: justUnlocked)
                if !isLast {
                    Rectangle()
                        .fill(state == .done ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.3)))
                        .frame(width: 3)
                        .frame(minHeight: 36, maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Chặng \(stage.number): \(stage.title)").font(.headline)
                Text("Từ vựng \(progress.learned)/\(progress.total) · \(stage.grammar.name): \(passed ? "đạt" : "chưa đạt")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
            Spacer()
        }
        .opacity(state == .locked ? 0.5 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chặng \(stage.number): \(stage.title), \(state.label)")
        .accessibilityIdentifier("stage-\(stage.number)")
    }
}

struct StageNode: View {
    enum State {
        case done, current, locked
        var label: String { self == .done ? "đã xong" : self == .current ? "đang học" : "chưa mở" }
    }
    let state: State
    let justUnlocked: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var bounce = 0

    var body: some View {
        Image(systemName: state == .done ? "checkmark" : state == .current ? "play.fill" : "lock.fill")
            .font(.headline)
            .foregroundStyle(state == .locked ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
            .frame(width: 40, height: 40)
            .background(state == .locked ? AnyShapeStyle(.secondary.opacity(0.2)) : AnyShapeStyle(.tint), in: .circle)
            .symbolEffect(.pulse, options: .repeating, isActive: state == .current && !reduceMotion)
            .symbolEffect(.bounce, options: .repeat(3), value: bounce)
            .scaleEffect(justUnlocked && bounce == 0 && !reduceMotion ? 0.6 : 1)
            .task {
                guard justUnlocked else { return }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.6)) { bounce += 1 }
            }
    }
}

/// Chi tiết một chặng: chủ đề từ vựng và bài ngữ pháp.
struct StageDetailView: View {
    let stage: Stage
    @Query private var topics: [Topic]
    @AppStorage(Settings.grammarScoresKey) private var scores = GrammarScores()

    var body: some View {
        let p = Roadmap.vocabProgress(stage, topics: topics)
        List {
            Section("Từ vựng") {
                if let topic = Roadmap.topic(stage, in: topics) {
                    NavigationLink { TopicDetailView(topic: topic) } label: {
                        LabeledContent(stage.title, value: "\(p.learned)/\(p.total)")
                    }
                } else {
                    LabeledContent(stage.title, value: "\(p.total) từ")
                }
            }
            Section("Ngữ pháp") {
                NavigationLink { GrammarLessonView(topic: stage.grammar) } label: {
                    LabeledContent(stage.grammar.name) { BestScore(topic: stage.grammar) }
                }
            }
        }
        .navigationTitle("Chặng \(stage.number)")
    }
}
