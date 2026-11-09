import SwiftUI
import WidgetKit

private let widgetGroupId = "group.com.mypocket.app"

private struct AgendaEvent: Decodable, Identifiable {
  let title: String
  let day: String
  let time: String
  let timestamp: Double

  var id: Double { timestamp }
  var startsAt: Date { Date(timeIntervalSince1970: timestamp / 1000) }
}

private struct CalendarEntry: TimelineEntry {
  let date: Date
  let events: [AgendaEvent]
}

private struct CalendarProvider: TimelineProvider {
  func placeholder(in context: Context) -> CalendarEntry {
    CalendarEntry(
      date: Date(),
      events: [AgendaEvent(title: "Reunión", day: "Hoy", time: "10:00", timestamp: Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000)]
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
    completion(CalendarEntry(date: Date(), events: readEvents()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
    let now = Date()
    let events = readEvents()
    var entries = [CalendarEntry(date: now, events: events)]
    entries.append(contentsOf: events
      .filter { $0.startsAt > now }
      .map { CalendarEntry(date: $0.startsAt, events: events) })
    completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(6 * 60 * 60))))
  }

  private func readEvents() -> [AgendaEvent] {
    guard
      let defaults = UserDefaults(suiteName: widgetGroupId),
      let json = defaults.string(forKey: "agendaEvents"),
      let data = json.data(using: .utf8),
      let events = try? JSONDecoder().decode([AgendaEvent].self, from: data)
    else {
      return []
    }
    return events.sorted { $0.startsAt < $1.startsAt }
  }
}

private struct CalendarWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: CalendarEntry

  private var upcomingEvents: [AgendaEvent] {
    Array(entry.events.filter { $0.startsAt > entry.date }.prefix(family == .systemSmall ? 2 : 3))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Agenda MyPocket")
        .font(.headline)
        .foregroundStyle(.white)

      if upcomingEvents.isEmpty {
        Text("No hay próximos eventos")
          .font(.subheadline)
          .foregroundStyle(Color.white.opacity(0.82))
        Spacer(minLength: 0)
      } else {
        ForEach(upcomingEvents) { event in
          VStack(alignment: .leading, spacing: 2) {
            Text("\(event.day) · \(event.time)")
              .font(.caption)
              .foregroundStyle(Color(red: 0.75, green: 0.90, blue: 0.85))
            Text(event.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 0)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(red: 0.09, green: 0.42, blue: 0.36))
    .widgetURL(URL(string: "mypocket://"))
  }
}

@main
struct MyPocketCalendarWidget: Widget {
  let kind = "MyPocketCalendarWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
      CalendarWidgetView(entry: entry)
    }
    .configurationDisplayName("Agenda MyPocket")
    .description("Consulta tus próximos eventos y reuniones.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
