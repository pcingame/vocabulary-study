import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var words: [Word]
    private let log = StudyLog.counts
    private let cal = Calendar.current

    var body: some View {
        List {
            Section {
                HStack {
                    tile("Mới", .new, .gray)
                    tile("Đang học", .learning, .hardInk)
                    tile("Đã thuộc", .mastered, .easyInk)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section("30 ngày qua") {
                Chart(days(30), id: \.self) { date in
                    BarMark(x: .value("Ngày", date, unit: .day), y: .value("Thẻ", count(date)))
                        .foregroundStyle(.tint)
                }
                .frame(height: 180)
                .padding(.vertical, 8)
                .accessibilityIdentifier("statsChart")
            }
            Section {
                heatmap
            } header: {
                Text("12 tuần qua")
            } footer: {
                Text("Ô càng đậm là ngày học càng nhiều thẻ.")
            }
        }
        .navigationTitle("Thống kê")
    }

    private func tile(_ title: String, _ status: Word.Status, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(words.filter { $0.status == status }.count)").font(.title.bold()).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    /// Mỗi cột là 1 tuần, mỗi ô là 1 ngày (thứ Hai ở trên).
    private var heatmap: some View {
        let today = cal.startOfDay(for: .now)
        let weekday = (cal.component(.weekday, from: today) + 5) % 7  // thứ Hai = 0
        let start = cal.date(byAdding: .day, value: -weekday - 7 * 11, to: today)!
        return HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { week in
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { d in
                        let date = cal.date(byAdding: .day, value: week * 7 + d, to: start)!
                        RoundedRectangle(cornerRadius: 3)
                            .fill(date > today ? Color.clear : count(date) == 0 ? Color.secondary.opacity(0.15)
                                  : Color.accentColor.opacity(min(1, 0.3 + Double(count(date)) / 40)))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement()
        .accessibilityLabel("Đã học \(days(84).filter { count($0) > 0 }.count) trong 84 ngày qua")
    }

    private func count(_ date: Date) -> Int { log[StudyLog.day(date)] ?? 0 }

    /// `n` ngày gần nhất, tính cả hôm nay.
    private func days(_ n: Int) -> [Date] {
        (0..<n).reversed().map { cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: .now))! }
    }
}
