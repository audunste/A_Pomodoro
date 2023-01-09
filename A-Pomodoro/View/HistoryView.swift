//
//  HistoryView.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 03/01/2023.
//

import SwiftUI
import CoreData


struct HistoryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) var viewContext
    @EnvironmentObject var modelData: ModelData

    var body: some View {
        VStack() {
            ConfiguredHistoryView(config:
                HistoryConfig(
                    fromDay: ADay.today - 13,
                    granularity: TimeInterval.day))
        }
    }
}

struct HistoryConfig {
    let fromDay: ADay
    let granularity: TimeInterval
}

struct ConfiguredHistoryView: View {

    let config: HistoryConfig
    
    var body: some View {
        FetchedHistoryView(
            config: config,
            pomodoroEntries: FetchRequest(
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
                predicate: NSPredicate(format:"startDate >= %@ AND timerType == 'pomodoro'", config.fromDay.date as NSDate)))
    }
}

struct FetchedHistoryView: View {
    @EnvironmentObject var modelData: ModelData
    let config: HistoryConfig
    @FetchRequest var pomodoroEntries: FetchedResults<PomodoroEntry>
    
    func getDateString(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date)
    }

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
    
    var maxCount: Int {
        var maxValue = 0
        for group in groupedEntries {
            maxValue = max(group.items.count, maxValue)
        }
        return maxValue
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HistoryHeader()
                .frame(width: geometry.size.width, height: 72, alignment: .topLeading)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let maxCount = self.maxCount
                        ForEach(groupedEntries) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(getDateString(date: group.id.date))
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.33))
                                .frame(alignment: .leading)
                                HStack {
                                    Rectangle()
                                    .frame(width: (geometry.size.width - 48) * Double(group.items.count) / Double(maxCount))
                                    .foregroundColor(modelData.appColor.backgroundColor)
                                    Text("\(group.items.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 16)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 12)
                }
                .background(.white)
                .foregroundColor(.black)
                .frame(width: geometry.size.width, height: geometry.size.height - 72)
                .fixedSize(horizontal: true, vertical: true)
                .offset(y: 72)
            }
            .frame(alignment: .topLeading)
        }
    }
}

class PreviewHistoryViewModel: HistoryViewModel {
    
    let peopleCount: Int
    
    init(viewContext: NSManagedObjectContext, peopleCount: Int) {
        self.peopleCount = peopleCount
        super.init(viewContext: viewContext)
    }
    
    override func updatePeople() {
        super.updatePeople()
        switch peopleCount {
        case 2:
            self.people = [
                self.people[0],
                Person(name: "Audun", pomodoroCount: 678)
            ]
        case 3:
            self.people = [
                self.people[0],
                Person(name: "Audun", pomodoroCount: 678),
                Person(name: "Tobias", pomodoroCount: 1782),
            ]
        default:
            return
        }
    }
}

struct HistoryView_Previews: PreviewProvider {

    static let persistentContainer = PersistenceController.preview.persistentContainer
    static let viewModel = HistoryViewModel(viewContext: persistentContainer.viewContext)
    static let viewModel2 = PreviewHistoryViewModel(viewContext: persistentContainer.viewContext, peopleCount: 2)

    static var previews: some View {
        HistoryView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewDisplayName("SE portrait")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environmentObject(viewModel)

        HistoryView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewDisplayName("Two people")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environmentObject(viewModel2 as HistoryViewModel)

        HistoryView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewDisplayName("Three people")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environmentObject(PreviewHistoryViewModel(viewContext: persistentContainer.viewContext, peopleCount: 3) as HistoryViewModel)

        HistoryView()
        .previewDisplayName("SE landscape")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .previewInterfaceOrientation(.landscapeLeft)
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environmentObject(viewModel)
    }
}
