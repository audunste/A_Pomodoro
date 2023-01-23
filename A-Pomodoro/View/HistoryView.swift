//
//  HistoryView.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 03/01/2023.
//

import SwiftUI
import CoreData


struct HistoryView: View {
    @Environment(\.managedObjectContext) var viewContext
    @EnvironmentObject var historyViewModel: HistoryViewModel
    
    var body: some View {
        VStack {
            ConfiguredHistoryView(config:
                HistoryConfig(
                    historyId: historyViewModel.activeId,
                    fromDay: ADay.today - 179,
                    granularity: TimeInterval.day))
        }
        .onAppear {
            if historyViewModel.viewContext == nil {
                historyViewModel.viewContext = viewContext
            }
            updateActiveId()
        }
        .onChange(of: historyViewModel.people) {
            people in
            ALog("onChange people")
            updateActiveId()
        }
    }
    
    func updateActiveId() {
        if historyViewModel.activeId == nil && historyViewModel.people.count > 0 {
            historyViewModel.activeId = historyViewModel.people[0].id
        }
    }
}

struct HistoryConfig {
    let historyId: NSManagedObjectID?
    let fromDay: ADay
    let granularity: TimeInterval
}

struct ConfiguredHistoryView: View {

    let config: HistoryConfig
    @Environment(\.managedObjectContext) var viewContext
    
    var history: History? {
        if let id = config.historyId {
            return try? viewContext.existingObject(with: id) as? History
        }
        return nil
    }
    
    var pomodoroEntryFetchRequest: FetchRequest<PomodoroEntry> {
        if let history = history {
            ALog("HistoryView has a history")
            return FetchRequest(
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
                predicate: NSPredicate(format:"startDate >= %@ AND timerType == 'pomodoro' AND task != nil AND task.category.history = %@", config.fromDay.date as NSDate, history))
        }
        return FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(value: false))
    }
    
    var body: some View {
        FetchedHistoryView(
            config: config,
            pomodoroEntries: pomodoroEntryFetchRequest)
    }
}

struct FetchedHistoryView: View {
    @EnvironmentObject var modelData: ModelData
    let config: HistoryConfig
    @FetchRequest var pomodoroEntries: FetchedResults<PomodoroEntry>
    
    #if os(macOS)
    let showFooter = true
    #else
    let showFooter = false
    #endif
    
    func getDateString(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date)
    }

    var groupedEntries: [IdentifiableGroup<ADay, PomodoroEntry>] {
        var groupsByDay = [ADay: IdentifiableGroup<ADay, PomodoroEntry>]()
        if pomodoroEntries.isEmpty {
            return []
        }
        var minDay = ADay.max
        var maxDay: ADay = 0
        for entry in pomodoroEntries {
            guard let startDate = entry.startDate else {
                continue
            }
            let entryDay = ADay.of(date: startDate)
            minDay = min(entryDay, minDay)
            maxDay = max(entryDay, maxDay)
            if let group = groupsByDay[entryDay] {
                group.append(entry)
            } else {
                let group = IdentifiableGroup<ADay, PomodoroEntry>(id: entryDay)
                group.append(entry)
                groupsByDay[entryDay] = group
            }
        }
        for day in minDay...maxDay {
            guard let _ = groupsByDay[day] else {
                let group = IdentifiableGroup<ADay, PomodoroEntry>(id: day)
                groupsByDay[day] = group
                continue
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
                        ForEach(Array(groupedEntries.enumerated()), id: \.element) {
                            index, group in
                            VStack(alignment: .leading, spacing: 0) {
                                let weekday = Calendar.current.component(.weekday, from: group.id.date)
                                
                                if (index == 0 || (weekday - 1) == (Calendar.current.firstWeekday + 5) % 7) {
                                    Text(getDateString(date: group.id.date))
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(white: 0.33))
                                    .frame(alignment: .leading)
                                    .padding(.top, index > 0 ? 12 : 0)
                                    .padding(.bottom, 2)
                                }
                                
                                HStack(spacing: 4) {
                                    Rectangle()
                                    .frame(width: max(2, (geometry.size.width - 72) * Double(group.items.count) / Double(maxCount)))
                                    .foregroundColor(modelData.appColor.backgroundColor)
                                    
                                    let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
                                    
                                    Text("\(String(weekdayName.prefix(3)))")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(Color(white: 0.33))
                                    if group.items.count > 0 {
                                        Text("\(group.items.count)")
                                        .font(.system(size: 10, weight: .semibold))
                                    }
                                }
                                
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 16)
                            .padding(.top, 4)
                        }
                        if maxCount == 0 {
                            Spacer()
                            .frame(maxWidth: .infinity)
                        }
                        
                    }
                    .padding(.top, 12)
                }
                .background(.white)
                .foregroundColor(.black)
                .frame(width: geometry.size.width, height: geometry.size.height - 72 - (showFooter ? 56 : 0))
                .fixedSize(horizontal: true, vertical: true)
                .offset(y: 72)
                
                if (showFooter) {
                    HistoryFooter()
                    .offset(y: geometry.size.height - 56)
                    .frame(width: geometry.size.width, height: 56)
                    .fixedSize(horizontal: true, vertical: true)
                }
            }
            .frame(alignment: .topLeading)
        }
    }
}

struct HistoryFooter: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var modelData: ModelData
    
    var body: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(NormalButton())
            Spacer()
            .frame(width: 16)
        }
        .frame(maxHeight: .infinity)
        .background(modelData.appColor.backgroundColor)
        .foregroundColor(modelData.appColor.textColor)
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
                Person(historyId: History(context: self.viewContext!).objectID, name: "Audun", pomodoroCount: 678)
            ]
        case 3:
            self.people = [
                self.people[0],
                Person(historyId: History(context: self.viewContext!).objectID, name: "Audun", pomodoroCount: 678),
                Person(historyId: History(context: self.viewContext!).objectID, name: "Tobias", pomodoroCount: 1782),
            ]
        default:
            return
        }
    }
}

struct HistoryView_Previews: PreviewProvider {

    static let persistentContainer = PersistenceController.preview.persistentContainer
    static let viewModel = HistoryViewModel(viewContext: persistentContainer.viewContext)

    static var previews: some View {
        HistoryView()
        //.frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewDisplayName("SE portrait")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environmentObject(viewModel)

        HistoryView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewDisplayName("Two people")
        .withPreviewEnvironment("iPhone 14")
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environmentObject(PreviewHistoryViewModel(viewContext: persistentContainer.viewContext, peopleCount: 2) as HistoryViewModel)

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
        
        HistoryView()
        .withPreviewEnvironment("iPad (10th generation)")
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environmentObject(viewModel)
        
    }
}
