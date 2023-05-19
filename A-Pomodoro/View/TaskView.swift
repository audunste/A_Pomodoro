//
//  TaskView.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 01/05/2023.
//

import SwiftUI
import EventKit

struct TaskContent: View {
    var selectTaskHandler: () -> Void

    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.mainWindowSize) var mainWindowSize
    @StateObject var controller = PersistenceController.active
    @State var task: Task? = nil

    private var title: String? {
        task?.title
    }
    
    private var isDefaultTask: Bool {
        guard let title = title else {
            return true
        }
        return title.isEmpty
    }
    
    private var canTaskBeCompleted: Bool {
        guard let title = title else {
            return false
        }
        return !title.isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            if canTaskBeCompleted {
                Button {
                    completeTask()
                } label: {
                    Image(systemName: "circle")
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(IconButton2())
            }
            Text(title ?? "Select Task")
            .font(.system(size: mainWindowSize.width < 390 ? 14 : 16))
            Spacer()
            .frame(width: 4)
            Button {
                selectTaskHandler()
            } label: {
                Image(systemName: "chevron.down.circle")
                .frame(width: 24, height: 24)
            }
            .buttonStyle(IconButton2())
        }
        .opacity(isDefaultTask ? 0.9 : 1.0)
        .onChange(of: controller.activeTaskId) {
            newTask in
            self.task = controller.getActiveTask(context: viewContext)
        }
        .onAppear {
            self.task = controller.getActiveTask(context: viewContext)
        }
    }
    
    func completeTask() {
        guard let task = task else {
            ALog(level: .warning, "No task to complete")
            return
        }
        let store = EKEventStore()
        let reminderLists = store.calendars(for: .reminder)
        guard let list = reminderLists.first(where: { $0.title == task.title }) else {
            ALog(level: .warning, "No Reminders List matching \(task.title!)")
            return
        }
        let pred = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [list])
        store.fetchReminders(matching: pred, completion: {(_ reminders: [Any]?) -> Void in
            guard let reminders = reminders as? [EKReminder?] else {
                ALog("Did not get EKReminder list from fetchReminders")
                return
            }
            var match: EKReminder? = nil
            var next: EKReminder? = nil
            for reminder: EKReminder? in reminders {
                // Do something for each reminder.
                guard let reminder = reminder,
                    let title = reminder.title
                else {
                    ALog("Reminder is nil")
                    continue
                }
                if match != nil && next == nil {
                    next = reminder
                } else if title == task.title {
                    match = reminder
                }
            }
            
            /*
            tempCats.append(tempCat)
            if tempCats.count == reminderLists.count {
                self.reminderCategories = tempCats
            }
            */
        })
        
        var match: EKReminder? = nil
    }
}


struct TaskView: View {
    var selectTaskHandler: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                let timerSize = min(Size.maxTimerWidth, geometry.size.height)
                let remainingWidth = geometry.size.width - timerSize
                let taskX0 = remainingWidth / 2 + timerSize
                TaskContent(selectTaskHandler: selectTaskHandler)
                .frame(width: remainingWidth / 2, height: geometry.size.height)
                .offset(x: taskX0, y: 0)
            } else {
                let tabContentHeight = geometry.size.height - Size.tabBarHeight
                let timerSize = min(Size.maxTimerWidth, geometry.size.width)
                let remainingHeight = tabContentHeight - timerSize
                let taskY0 = remainingHeight / 2 + timerSize
                TaskContent(selectTaskHandler: selectTaskHandler)
                .frame(width: geometry.size.width, height: remainingHeight / 2)
                .offset(x: 0, y: taskY0)
            }
        }
    }
}

struct TaskView_Previews: PreviewProvider {
    static var previews: some View {
        TaskView(selectTaskHandler: {})
        .previewDisplayName("SE portrait")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        
        TaskView(selectTaskHandler: {})
        .previewDisplayName("SE landscape")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .previewInterfaceOrientation(.landscapeLeft)

        TaskView(selectTaskHandler: {})
        .withPreviewEnvironment("iPhone 14 Pro Max")
        
        TaskView(selectTaskHandler: {})
        .withPreviewEnvironment("iPad (10th generation)")
        
    }
}
