import WidgetKit
import SwiftUI

struct DoNowHomeProvider: TimelineProvider {
    // Should match the group ID used in Flutter
    let appGroupId = "group.com.atomictask.donow"
    
    func placeholder(in context: Context) -> DoNowHomeEntry {
        DoNowHomeEntry(date: Date(), pendingCount: 3, nextTaskTitle: "Review Design", nextTaskTime: "14:00")
    }

    func getSnapshot(in context: Context, completion: @escaping (DoNowHomeEntry) -> ()) {
        let entry = DoNowHomeEntry(date: Date(), pendingCount: 3, nextTaskTitle: "Review Design", nextTaskTime: "14:00")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoNowHomeEntry>) -> ()) {
        // Read from UserDefaults shared with Flutter
        let userDefaults = UserDefaults(suiteName: appGroupId)
        
        let pendingCount = userDefaults?.integer(forKey: "pending_count") ?? 0
        let nextTaskTitle = userDefaults?.string(forKey: "next_task_title") ?? "No Tasks"
        let nextTaskTime = userDefaults?.string(forKey: "next_task_time") ?? ""
        
        let entry = DoNowHomeEntry(
            date: Date(),
            pendingCount: pendingCount,
            nextTaskTitle: nextTaskTitle,
            nextTaskTime: nextTaskTime
        )

        // Refresh every 15 minutes by default, but Flutter will force reload when data changes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct DoNowHomeEntry: TimelineEntry {
    let date: Date
    let pendingCount: Int
    let nextTaskTitle: String
    let nextTaskTime: String
}

struct DoNowHomeWidgetEntryView : View {
    var entry: DoNowHomeProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemSmall {
            SmallView(entry: entry)
        } else {
            MediumView(entry: entry)
        }
    }
}

struct SmallView: View {
    var entry: DoNowHomeProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("DO NOW")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("\(entry.pendingCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(entry.pendingCount > 0 ? .primary : .gray)
            
            Text("Pending")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color("WidgetBackground"))
    }
}

struct MediumView: View {
    var entry: DoNowHomeProvider.Entry
    
    var body: some View {
        HStack {
            // Left: Pending Count
            VStack(alignment: .leading) {
                Text(entry.date, style: .date)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(entry.pendingCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                
                Text("Tasks")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
            
            Divider()
                .padding(.vertical)
            
            // Right: Next Task
            VStack(alignment: .leading, spacing: 4) {
                Text("UP NEXT")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.green)
                    .padding(.top, 4)
                
                Spacer()
                
                Text(entry.nextTaskTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if !entry.nextTaskTime.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(entry.nextTaskTime)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color("WidgetBackground"))
    }
}

struct DoNowHomeWidget: Widget {
    let kind: String = "DoNowHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoNowHomeProvider()) { entry in
            DoNowHomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("See your pending tasks and what's up next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
