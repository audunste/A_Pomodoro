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
        let components = DateComponents(minute: 25)
        let futureDate = Calendar.current.date(byAdding: components, to: Date())!
        return SimpleEntry(endDate: futureDate)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let components = DateComponents(minute: 25)
        let futureDate = Calendar.current.date(byAdding: components, to: Date())!
        let entry = SimpleEntry(endDate: futureDate)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        let userDefaults = UserDefaults.group
        let isFocusType = userDefaults.bool(forKey: AppGroupKey.Timer.isFocusType)
        let futureDate = userDefaults.object(forKey: AppGroupKey.Timer.endDate) as? Date
        let timerSeconds = userDefaults.integer(forKey: AppGroupKey.Timer.seconds)
        
        if futureDate == nil {
            entries.append(SimpleEntry(isFocusType: isFocusType, progress: timerSeconds > 0 ? 0.5 : 0.2))
        } else {
            let currentDate = Date()
            let secondsUntil = futureDate!.timeIntervalSinceNow
            if secondsUntil > 0 {
                let minutesUntil = Int(ceil(secondsUntil / 60))
                for minutesOffset in 0..<minutesUntil {
                    let entryDate = Calendar.current.date(byAdding: .minute, value: minutesOffset, to: currentDate)!
                    let remaining = futureDate!.timeIntervalSince(entryDate)
                    let progress = timerSeconds > 0
                        ? (1.0 - Float(remaining) / Float(timerSeconds)).clamped(to: 0.0...1.0)
                        : 0.0
                    let entry = SimpleEntry(date: entryDate, endDate: futureDate, isFocusType: isFocusType, progress: progress)
                    entries.append(entry)
                }
                entries.append(SimpleEntry(date: futureDate, isFocusType: !isFocusType))
            } else {
                entries.append(SimpleEntry(isFocusType: !isFocusType))
            }
        }
        let timeline = Timeline(entries: entries, policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let endDate: Date?
    let isFocusType: Bool
    let progress: Float
}

extension SimpleEntry {
    init(date: Date? = nil, endDate: Date? = nil, isFocusType: Bool = true, progress: Float = 0) {
        self.init(date: date ?? Date(), endDate: endDate, isFocusType: isFocusType, progress: progress)
    }
}


struct RemainingWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            GeometryReader { geom in
                VStack {
                    Gauge(value: entry.progress, in: 0.0...1.0) {
                        Text(entry.isFocusType ? "Focus" : "Break")
                        .font(.system(size: 10))
                        .padding(.top, 2)
                    } currentValueLabel: {
                        if let endDate = entry.endDate {
                            Text(endDate, style: .timer)
                            .font(.title.monospacedDigit())
                        } else {
                            Image("PomodoroWidget")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.bottom, 4)
                                .opacity(0.9)
                        }
                    }
                    .gaugeStyle(.accessoryCircular)
                }
            }
        default:
            Text("A•Pomodoro")
        }
    }
}

struct RemainingWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.remaining, provider: Provider()) { entry in
            RemainingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("A•Pomodoro")
        .description("Shows remaining time and acts as a shortcut into the app to start the next stage")
        .supportedFamilies([.accessoryCircular])
    }
}

struct RemainingWidget_Previews: PreviewProvider {
    static var previews: some View {
        RemainingWidgetEntryView(entry: SimpleEntry(date: Date(), endDate: Calendar.current.date(byAdding: .minute, value: 25, to: Date())!))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            
        RemainingWidgetEntryView(entry: SimpleEntry(date: Date()))
        .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}
