//
//  TaskSheet.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 17/05/2023.
//

#if os(iOS)
import UIKit
#endif

import SwiftUI
import CoreData
import CloudKit
import EventKit

extension String {
    static var defaultTask: String {
        NSLocalizedString("Default Task", comment: "Name of default task")
    }
    static var defaultCategory: String {
        NSLocalizedString("Default Category", comment: "Name of default category")
    }
}

enum TaskStatus {
    case todo
    case completed
    case cancelled
    case incompletable
}

struct TempTask: Hashable, Identifiable {
    var title: String
    var status: TaskStatus
    var id: String { title }
    init(task: Task) {
        self.title = task.title ?? .defaultTask
        self.status = task.title == nil ? .incompletable : .cancelled
    }
    init(reminder: EKReminder) {
        self.title = reminder.title
        self.status = reminder.isCompleted ? .completed : .todo
    }
}

struct TempCategory: Hashable {
    var title: String
    var tasks: [TempTask]
}

struct TaskSheet: View {
    #if os(macOS)
    let showFooter = true
    #else
    let showFooter = false
    #endif
  
    @EnvironmentObject var lastPomodoroEntryBinder: LatestObjectBinder<PomodoroEntry>
    @EnvironmentObject var taskModel: TaskModel
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("focusAndBreakStage") private var focusAndBreakStage = 0
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
            ALog("self.activeTask: \(String(describing: self.activeTask))")
        }
        .onChange(of: taskModel.mergedCategories) {
            newCats in
            guard let presentedCategory = presentedCategories.last else {
                return
            }
            ALog("mergedCategories changed, checking if view needs update")
            if let match = newCats.first(where: { $0.title == presentedCategory.title }),
                match != presentedCategory
            {
                var modPresented = self.presentedCategories
                modPresented[modPresented.count - 1] = match
                self.presentedCategories = modPresented
                updateActiveTask()
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            taskModel.updateReminderCategories()
        }
        #endif
        .onAppear {
            updateActiveTask()
        }
        .onDisappear {
            ALog("onDisappear cat: \(self.activeTask ?? "nil") task: \(self.activeCategory ?? "nil")")
            applyActiveTask()
        }
        
    }
    
    var selectedCategoryTitle: String? {
        activeCategory == String.defaultCategory ? nil : activeCategory
    }
    
    var selectedTaskTitle: String? {
        activeTask == String.defaultTask ? nil : activeTask
    }
    
    func applyActiveTask() {
        let controller = PersistenceController.active
        controller.applyActiveTask(viewContext, taskTitle: self.selectedTaskTitle, categoryTitle: self.selectedCategoryTitle, completion:
        {
            task in
            // if focus pomodoro in progress, change its task
            if let entry = lastPomodoroEntryBinder.managedObject {
                if entry.isRunning && entry.stage % 2 == 0 {
                    entry.task = task
                    try viewContext.save()
                    return
                }
            }
            // else ensure pomodoro stage with 25 timer
            focusAndBreakStage = ((focusAndBreakStage + 4) / 4) * 4
        })
    }

    func updateActiveTask() {
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

struct CategoryList: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\.title)]) var categories: FetchedResults<Category>
    @EnvironmentObject var taskModel: TaskModel
    @State var showSyncButton: Bool = false
    @Binding var activeCategory: String?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TaskHeader()
                .fixedSize(horizontal: false, vertical: true)
                List {
                    ForEach(taskModel.mergedCategories, id: \.title) {
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
        taskModel.updateReminderCategories()
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

struct TaskItem: View {
    var categoryTitle: String
    var task: TempTask
    var isSelected: Bool
    var selectTaskHandler: () -> Void
    @EnvironmentObject var taskModel: TaskModel
    
    var body: some View {
        HStack(spacing: 0) {
            if task.status == .todo || task.status == .completed {
                Button {
                    ALog("onTap Task Complete")
                    completeTask()
                } label: {
                    let isChecked = task.status == .completed || task == taskModel.completingTask
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 12)
                }
                .buttonStyle(UnstyledButton())
            }
            Button {
                ALog("onTap Task")
                selectTaskHandler()
            } label: {
                HStack {
                    Text(task.title)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(UnstyledButton())
        }
        .listRowBackground(isSelected ? Color(white: 0.5, opacity: 0.4) : Color(white: 0.5, opacity: 0.0001))
    }
    
    func completeTask() {
        guard task != taskModel.completingTask else {
            return
        }
        TaskModel.completeTask(taskTitle: task.title, categoryTitle: categoryTitle, activateNext: isSelected) { callback in
            switch(callback) {
            case .fail:
                taskModel.completingTask = nil
            case .processing:
                taskModel.completingTask = task
            case .complete:
                updateSoon()
            }
        }
    }
    
    func updateSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            taskModel.updateReminderCategories()
        }
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
        let todoTasks = category.tasks.filter({ $0.status == .todo })
        let completedTasks = category.tasks.filter({ $0.status == .completed })
        let cancelledTasks = category.tasks.filter({ $0.status == .cancelled })
        let showSections = completedTasks.count > 0 || cancelledTasks.count > 0
        
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
                if showSections {
                    Section(header: Text("Todo")) {
                        ForEach(todoTasks) {
                            task in
                            TaskItem(
                                categoryTitle: category.title,
                                task: task,
                                isSelected: activeTask == task.title,
                                selectTaskHandler: {
                                    self.activeTask = task.title
                                })
                        }
                    }
                    if completedTasks.count > 0 {
                        Section(header: Text("Completed")) {
                            ForEach(completedTasks) {
                                task in
                                TaskItem(
                                    categoryTitle: category.title,
                                    task: task,
                                    isSelected: activeTask == task.title,
                                    selectTaskHandler: {
                                        self.activeTask = task.title
                                    })
                            }
                        }
                    }
                    if cancelledTasks.count > 0 {
                        Section(header: Text("Cancelled")) {
                            ForEach(cancelledTasks) {
                                task in
                                TaskItem(
                                    categoryTitle: category.title,
                                    task: task,
                                    isSelected: activeTask == task.title,
                                    selectTaskHandler: {
                                        self.activeTask = task.title
                                    })
                            }
                        }
                    }
                } else {
                    ForEach(category.tasks) {
                        task in
                        TaskItem(
                            categoryTitle: category.title,
                            task: task,
                            isSelected: activeTask == task.title,
                            selectTaskHandler: {
                                self.activeTask = task.title
                            })
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: .infinity)
            .background(Color("Background"))
            .foregroundColor(Color("PrimaryText"))
        }
        .onChange(of: activeTask) {
            newTask in
            ALog("detail new task: \(String(describing: newTask))")
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
