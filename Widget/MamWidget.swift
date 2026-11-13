import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
    let date: Date
    let day: WidgetSnapshot.Day?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, day: .init(start: .now, streak: 7, due: 12)) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Entry(date: .now, day: WidgetSnapshot.load()?.day(at: .now)))
    }

    /// Một mục cho bây giờ và một mục cho mỗi ngày sau đó trong bản tóm tắt (đổi lúc nửa đêm).
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let now = Date.now
        var entries = [Entry(date: now, day: snapshot?.day(at: now))]
        for day in snapshot?.days ?? [] where day.start > now { entries.append(Entry(date: day.start, day: day)) }
        completion(Timeline(entries: entries, policy: .never))  // app gọi reload mỗi khi số liệu đổi
    }
}

struct MamWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let streak = entry.day?.streak ?? 0
        let status = entry.day.map { $0.due > 0 ? "\($0.due) thẻ cần học" : "Xong hôm nay ✓" } ?? "Mở app để bắt đầu"
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("\(streak) ngày liên tiếp", systemImage: "leaf.fill").font(.headline)
                Text(status)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "leaf.fill").font(.title).foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text("\(streak)").font(.system(size: 40, weight: .bold, design: .rounded))
                Text("ngày liên tiếp").font(.caption).foregroundStyle(.secondary)
                Text(status).font(.footnote.weight(.semibold)).foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

@main
struct MamWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MamWidget", provider: Provider()) { entry in
            MamWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Mầm")
        .description("Chuỗi ngày học và số thẻ cần học hôm nay.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
