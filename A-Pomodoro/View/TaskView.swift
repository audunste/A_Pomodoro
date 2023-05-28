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
    @EnvironmentObject var lastPomodoroEntryBinder: LatestObjectBinder<PomodoroEntry>
    @EnvironmentObject var taskModel: TaskModel
    @StateObject var controller = PersistenceController.active
    @State var task: Task? = nil
    @State var completion: Bool? = nil
    @AppStorage("focusAndBreakStage") private var focusAndBreakStage = 0

    private var title: String? {
        task?.title
    }
    
    private var isDefaultTask: Bool {
        guard let title = title else {
            return true
        }
        return title.isEmpty
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if let completion = completion {
                Button {
                    if !completion {
                        completeTask()
                    }
                } label: {
                    Image(systemName: completion ? "checkmark.circle.fill" : "circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                }
                .frame(width: 32, height: 32)
                .buttonStyle(IconButton2())
            } else if !isDefaultTask {
                Spacer().frame(width: 32, height: 32)
            }
            Text(title ?? "Select Task")
            .font(.system(size: mainWindowSize.width < 390 ? 14 : 16))
            Spacer()
            .frame(width: 4)
            Button {
                selectTaskHandler()
            } label: {
                Image(systemName: "chevron.down.circle")
                .resizable()
                .frame(width: 20, height: 20)
            }
            .frame(width: 32, height: 32)
            .buttonStyle(IconButton2())
        }
        .opacity(isDefaultTask ? 0.9 : 1.0)
        .onChange(of: controller.activeTaskId) {
            newTask in
            self.completion = nil
            self.task = controller.getActiveTask(context: viewContext)
            updateCompletion()
        }
        .onChange(of: lastPomodoroEntryBinder.managedObject) {
            newEntry in
            if self.task == nil {
                if let entry = newEntry {
                    if entry.isRunning && entry.task != nil {
                        controller.setActiveTask(entry.task, viewContext)
                    }
                }
            }
        }
        .onChange(of: taskModel.reminderCategories) {
            newCats in
            ALog("newCats.count=\(newCats.count)")
            self.task = controller.getActiveTask(context: viewContext)
            updateCompletion()
        }
        .onAppear {
            self.task = controller.getActiveTask(context: viewContext)
            taskModel.updateReminderCategories()
        }
    }
    
    func updateCompletion() {
        guard let task = task,
            let title = title,
            !title.isEmpty,
            let categoryTitle = task.category?.title,
            let tempCat = taskModel.reminderCategories.first(where: { $0.title == categoryTitle }),
            let tempTask = tempCat.tasks.first(where: { $0.title == title })
        else {
            ALog(level: .warning, "No task to complete")
            return
        }
        switch (tempTask.status) {
        case .completed:
            self.completion = true
        case .todo:
            self.completion = false
        default:
            self.completion = nil
        }
    }
    
    func completeTask() {
        TaskModel.completeTask(task: task, activateNext: true) { callback in
            switch(callback) {
            case .fail:
                self.completion = nil
            case .processing:
                self.completion = true
            default:
                break
            }
        }
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
