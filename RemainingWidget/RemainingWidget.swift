//
//  RemainingWidget.swift
//  RemainingWidget
//
//  Created by Audun Steinholm on 01/03/2023.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let components = DateComponents(minute: 15)
        let futureDate = Calendar.current.date(byAdding: components, to: Date())!
        entries.append(SimpleEntry(date: futureDate))
        /*
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }
         */

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct RemainingWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            GeometryReader { geom in
                VStack {
                    Gauge(value: 2, in: 0...25) {
                        Image("PomodoroWidget")
                            .resizable()
                            .frame(width: 16, height: 16)
                    } currentValueLabel: {
                        Text(entry.date, style: .timer)
                    } /* minimumValueLabel: {
                       Text("\(Int(25))")
                       } maximumValueLabel: {
                       Text("\(Int(0))")
                       } */
                    .gaugeStyle(.accessoryCircular)
                }
            }
        default:
            Text("A•Pomodoro")
        }
    }
}

struct RemainingWidget: Widget {
    let kind: String = "RemainingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RemainingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.accessoryCircular, .systemSmall, .systemMedium, .systemLarge])
    }
}

struct RemainingWidget_Previews: PreviewProvider {
    static var previews: some View {
        RemainingWidgetEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}
