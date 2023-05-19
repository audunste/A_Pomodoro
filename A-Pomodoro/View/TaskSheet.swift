//
//  TaskSheet.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 17/05/2023.
//

import SwiftUI
import CoreData
import CloudKit
import EventKit

struct TempCategory: Hashable {
    var title: String
    var tasks: [String]
}

struct TaskSheet: View {
    #if os(macOS)
    let showFooter = true
    #else
    let showFooter = false
    #endif
  
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    @State private var presentedCategories: [TempCategory] = []
    @State var activeCategory: String?
    @State var activeTask: String?

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $presentedCategories) {
                CategoryList(activeCategory: $activeCategory)
                .navigationDestination(for: TempCategory.self) { category in
                    TaskList(category: category, activeTask: $activeTask)
                    .navigationBarBackButtonHidden()
                    .transition(.move(edge: .trailing))
                }
            }
            .tint(Color("BarText"))
            .background(Color("BarBackground"))
            .environment(\.up, {
                withAnimation(.easeInOut(duration: 0.175)) {
                    _ = presentedCategories.popLast()
                }
            })
            
            if showFooter {
                SheetBottomBar()
            }
        }
        .onChange(of: activeTask) {
            newTask in
            if presentedCategories.count > 0 {
                self.activeCategory = presentedCategories[0].title
                ALog("self.activeCategory: \(String(describing: self.activeCategory))")
            }
        }
        .onAppear {
            initActiveTask()
        }
        .onDisappear {
            ALog("onDisappear cat: \(self.activeTask ?? "nil") task: \(self.activeCategory ?? "nil")")
        }
    }

    func initActiveTask() {
        viewContext.perform {
            guard let task = PersistenceController.active.getAssignOrCreateActiveTask(context: viewContext) else {
                ALog(level: .warning, "No active task")
                return
            }
            guard let category = task.category else {
                ALog(level: .warning, "No active category")
                return
            }
            self.activeTask = task.title ?? .defaultTask
            self.activeCategory = category.title ?? .defaultCategory
            ALog("self.activeTask: \(self.activeTask ?? "nil")")
        }
    }

}

extension String {
    static var defaultTask: String {
        NSLocalizedString("Default Task", comment: "Name of default task")
    }
    static var defaultCategory: String {
        NSLocalizedString("Default Category", comment: "Name of default category")
    }
}

struct CategoryList: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\.title)]) var categories: FetchedResults<Category>
    @State var reminderCategories: [TempCategory] = []
    @State var showSyncButton: Bool = false
    @Binding var activeCategory: String?
    
    private var myCategories: [Category] {
        categories.filter { $0.isMine }
    }
    
    private var mergedCategories: [TempCategory] {
        var retval = [TempCategory]()
        for cat in myCategories {
            guard let tasks = cat.tasks else {
                continue
            }
            var tempTasks = [String]()
            for case let task as Task in tasks {
                tempTasks.append(task.title ?? .defaultTask)
            }
            if tempTasks.isEmpty {
                continue
            }
            retval.append(TempCategory(title: cat.title ?? .defaultCategory, tasks: tempTasks))
        }
        for tempCat in reminderCategories {
            if let i = retval.firstIndex(where: { $0.title == tempCat.title }) {
                for tempTask in tempCat.tasks {
                    if !retval[i].tasks.contains(tempTask) {
                        retval[i].tasks.append(tempTask)
                    }
                }
            } else {
                retval.append(tempCat)
            }
        }
        return retval
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TaskHeader()
                .fixedSize(horizontal: false, vertical: true)
                List {
                    ForEach(mergedCategories, id: \.title) {
                        cat in
                        CategoryItem(category: cat, isSelected: cat.title == activeCategory)
                    }
                    if showSyncButton {
                        Button {
                            ALog("Sync with ... Reminders")
                            let store = EKEventStore()
                            store.requestAccess(to: .reminder) {
                                granted, error in
                                if granted {
                                    ALog("Access granted")
                                    updateCategories()
                                } else {
                                    ALog("Access not granted")
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "checklist")
                                .frame(width: 24, height: 24)
                                Text("Sync with Reminders")
                                .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .foregroundColor(Color("BarText"))
                            .background(Color("BarBackground"))
                            .cornerRadius(24)
                        }
                        .buttonStyle(UnstyledButton())
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowSeparator(.hidden, edges: .bottom)
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: .infinity)
                .background(Color("Background"))
                .foregroundColor(Color("PrimaryText"))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            updateCategories()
        }
    }
        
    func updateCategories() {
        let authStatus = EKEventStore.authorizationStatus(for: .reminder)
        if authStatus == .notDetermined {
            self.showSyncButton = true
            return
        }
        if self.showSyncButton {
            self.showSyncButton = false
        }
        let store = EKEventStore()
        let reminderLists = store.calendars(for: .reminder)
        var tempCats = [TempCategory]()
        for list in reminderLists {
            let pred = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [list])
            var tempCat = TempCategory(title: list.title, tasks: [])
            store.fetchReminders(matching: pred, completion: {(_ reminders: [Any]?) -> Void in
                guard let reminders = reminders as? [EKReminder?] else {
                    ALog("Did not get EKReminder list from fetchReminders")
                    tempCats.append(tempCat)
                    if tempCats.count == reminderLists.count {
                        self.reminderCategories = tempCats
                    }
                    return
                }
                for reminder: EKReminder? in reminders {
                    // Do something for each reminder.
                    guard let reminder = reminder,
                        let title = reminder.title
                    else {
                        ALog("Reminder is nil")
                        continue
                    }
                    tempCat.tasks.append(title)
                }
                tempCats.append(tempCat)
                if tempCats.count == reminderLists.count {
                    self.reminderCategories = tempCats
                }
            })
        }
    }
}

struct CategoryItem: View {
    var category: TempCategory
    var isSelected: Bool
    
    var body: some View {
        NavigationLink(value: category) {
            Text(category.title)
        }
        .listRowBackground(isSelected ? Color(white: 0.5, opacity: 0.4) : Color.clear)
    }
}

struct TaskHeader: View {

    var body: some View {
        HStack {
            Text("Categories")
            .frame(height: 24)
            .font(.regularTitle)
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        }
        .frame(maxWidth: .infinity)
        .background(Color("BarBackground"))
        .foregroundColor(Color("BarText"))
    }
}

struct TaskList: View {
    @Environment(\.up) var up
    var category: TempCategory
    @Binding var activeTask: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    up?()
                } label: {
                    Image(systemName: "chevron.left")
                    .frame(width: 24, height: 24)
                    .padding(16)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                
                Spacer()
                
                Text(category.title)
                .font(.regularTitle)
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                
                Spacer()
                
                Spacer()
                    .frame(width: 24, height: 24)
                    .padding(16)
            }
            .frame(maxWidth: .infinity)
            .background(Color("BarBackground"))
            .foregroundColor(Color("BarText"))
            .fixedSize(horizontal: false, vertical: true)
            List {
                ForEach(category.tasks, id: \.self) {
                    task in
                    Button {
                        ALog("onTap Task")
                        self.activeTask = task
                    } label: {
                        Text(task)
                    }
                    .buttonStyle(.borderless)
                    .listRowBackground(activeTask == task ? Color(white: 0.5, opacity: 0.4) : Color.clear)
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: .infinity)
            .background(Color("Background"))
            .foregroundColor(Color("PrimaryText"))
        }
        .onAppear {
            ALog("activeTask: \(String(describing: activeTask))")
        }
    }
}

struct TaskSheet_Previews: PreviewProvider {
    static var previews: some View {
        TaskSheet()
    }
}
