//
//  HistoryView.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 03/01/2023.
//

import SwiftUI


struct HistoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var modelData: ModelData
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
        predicate: NSPredicate(format:"startDate >= %@", Date() as NSDate)
    ) var pomodoroEntries: FetchedResults<PomodoroEntry>

    var body: some View {
        VStack() {
            ConfiguredHistoryView(fromDay: ADay.today - 6, granularity: TimeInterval.day)
        }
    }
}

struct ConfiguredHistoryView: View {

    let fromDay: ADay
    let granularity: TimeInterval
    
    var body: some View {
        BarChart(
            fromDay: fromDay,
            granularity: granularity,
            pomodoroEntries: FetchRequest(
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
                predicate: NSPredicate(format:"startDate >= %@ AND timerType == 'pomodoro'", fromDay.date as NSDate)))
    }
}

struct BarChart: View {
    let fromDay: ADay
    let granularity: TimeInterval
    @FetchRequest var pomodoroEntries: FetchedResults<PomodoroEntry>

    var groupedEntries: [IdentifiableGroup<ADay, PomodoroEntry>] {
        var groupsByDay = [ADay: IdentifiableGroup<ADay, PomodoroEntry>]()
        for entry in pomodoroEntries {
            guard let startDate = entry.startDate else {
                continue
            }
            let entryDay = ADay.of(date: startDate)
            if let group = groupsByDay[entryDay] {
                group.append(entry)
            } else {
                let group = IdentifiableGroup<ADay, PomodoroEntry>(id: entryDay)
                group.append(entry)
                groupsByDay[entryDay] = group
            }
        }
        return groupsByDay.keys.sorted().reversed().map{ groupsByDay[$0]! }
    }

    var body: some View {
        ScrollView {
            ForEach(groupedEntries) { group in
                Text("Count on day \(group.id): \(group.items.count)")
                .font(.system(size: 10))
            }
        }
    }
}


struct HistoryView_Previews: PreviewProvider {

    static let persistentContainer = PersistenceController.preview.persistentContainer

    static var previews: some View {
        HistoryView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewDisplayName("SE portrait")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .environment(\.managedObjectContext, persistentContainer.viewContext)

        HistoryView()
        .previewDisplayName("SE landscape")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .previewInterfaceOrientation(.landscapeLeft)
        .environment(\.managedObjectContext, persistentContainer.viewContext)
    }
}
