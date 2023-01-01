//
//  TimerView.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 16/12/2022.
//

import SwiftUI
import CoreData

struct TimerView: View {

    static let multiplier: Int32 = 60
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var modelData: ModelData
    @EnvironmentObject var lastPomodoroEntryBinder: LatestObjectBinder<PomodoroEntry>
    var seconds: Int32
    var timerType: TimerType
    @State var timer: Timer? = nil
    @AppStorage("focusAndBreakStage") private var focusAndBreakStage = 0

    // calculated
    @State var remaining: Int32
    // temporary adjustment value
    @State var tempRemaining: Int32?

    init(_ minutes: Int32, timerType: TimerType) {
        seconds = minutes * TimerView.multiplier
        self.timerType = timerType
        _remaining = State(initialValue: seconds)
    }
    
    private var lastPomodoroEntry: PomodoroEntry? {
        lastPomodoroEntryBinder.managedObject
    }
    
    private var fastForwardDate: Date? {
        lastPomodoroEntryBinder.managedObject?.fastForwardDate
    }
    
    private var pauseDate: Date? {
        lastPomodoroEntryBinder.managedObject?.pauseDate
    }
    
    var displayedRemaining: Int32 {
        tempRemaining ?? remaining
    }

    
    var body: some View {
        SquareZStack {
            ProgressText(remaining: displayedRemaining)
            ProgressBow(buttonText: timer == nil ? NSLocalizedString("Start", comment: "Start button") : NSLocalizedString("Pause", comment: "Pause button"), remaining: remaining, total: seconds, tempRemaining: $tempRemaining, adjustmentHandler:
            {
                newRemaining in
                if let lastPomodoroEntry = relevantLastPomodoroEntryOrNil {
                    lastPomodoroEntry.adjustmentSeconds += 0.25 + Double(newRemaining) - lastPomodoroEntry.getRemaining()
                    viewContext.saveAndLogError()
                    updateRemaining()
                    updateNotification()
                } else if newRemaining != remaining {
                    let entry = PomodoroEntry(context: viewContext)
                    entry.startDate = Date()
                    entry.stage = Int64(getExpectedStage())
                    entry.timerType = timerType.rawValue
                    entry.timeSeconds = Double(seconds)
                    entry.pauseDate = entry.startDate
                    entry.adjustmentSeconds += Double(newRemaining) - Double(remaining)
                    viewContext.saveAndLogError()
                    print("apom new \(entry.timerType!)")
                    remaining = newRemaining
                }
            }, actionHandler: self.togglePlay)
        }
        .frame(maxWidth: 430, maxHeight: 430)
        .onChange(of: focusAndBreakStage) {
            stage in
            let stage = max(0, stage)
            if (getExpectedStage() != stage) {
                remaining = seconds
                stopTimerAndCancelNotificationIfNeeded()
            } else {
                print("apom maybe start \(timerType)")
            }
        }
        .onChange(of: lastPomodoroEntry) {
            entry in
            guard let entry = entry else {
                print("apom lastPomodoroEntry is nil in onChange")
                return
            }
            print("apom lastPomodoroEntry onChange \(String(describing: entry.timerType))")
            if focusAndBreakStage != entry.stage {
                print("apom setStage \(entry.stage), was \(focusAndBreakStage)")
                focusAndBreakStage = Int(entry.stage)
            }
            if !entry.isRunning {
                return
            }
            if entry.timerType ?? "nil" == timerType.rawValue {
                scheduleTimerAndNotificationIfNeeded()
            }
        }
        .onChange(of: fastForwardDate) {
            date in
            guard date != nil && isThisViewRelevantForLastPomodoroEntry else {
                return
            }
            if (timer == nil) {
                return
            }
            stopTimerAndCancelNotificationIfNeeded()
            remaining = seconds
            goToNextStage()
        }
        .onChange(of: pauseDate) {
            date in
            guard let lastPomodoroEntry = relevantLastPomodoroEntryOrNil else {
                return
            }
            if date == nil {
                if lastPomodoroEntry.isRunning {
                    scheduleTimerAndNotificationIfNeeded()
                }
            } else {
                stopTimerAndCancelNotificationIfNeeded()
                updateRemaining()
            }
        }
        .onAppear() {
            guard let lastPomodoroEntry = relevantLastPomodoroEntryOrNil else {
                return
            }
            if lastPomodoroEntry.isRunning {
                updateRemaining()
                scheduleTimerAndNotificationIfNeeded()
            }
        }
    }
    
    var relevantLastPomodoroEntryOrNil: PomodoroEntry? {
        if isThisViewRelevantForLastPomodoroEntry {
            return lastPomodoroEntry!
        }
        return nil
    }
    
    var isThisViewRelevantForLastPomodoroEntry: Bool {
        guard let lastPomodoroEntry = lastPomodoroEntry else {
            return false
        }
        return lastPomodoroEntry.timerType ?? "nil" == timerType.rawValue
    }
    
    func maybeHandleNewPomodoroEntry() {
    }
    
    func togglePlay() {
        guard let lastPomodoroEntry = lastPomodoroEntry else {
            return
        }
        if timer == nil {
            if lastPomodoroEntry.isPaused
                && lastPomodoroEntry.timerType == timerType.rawValue
            {
                let duration = -lastPomodoroEntry.pauseDate!.timeIntervalSinceNow
                lastPomodoroEntry.pauseSeconds += duration
                lastPomodoroEntry.pauseDate = nil
                viewContext.saveAndLogError()
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) {
                    t in
                    updateRemaining()
                }
            } else {
                let entry = PomodoroEntry(context: viewContext)
                entry.startDate = Date()
                entry.stage = Int64(getExpectedStage())
                entry.timerType = timerType.rawValue
                entry.timeSeconds = Double(seconds)
                viewContext.saveAndLogError()
                print("apom new \(entry.timerType!)")
                remaining = seconds - 1
            }
            scheduleTimerAndNotificationIfNeeded()
            changeStageIfNeeded()
        } else {
            lastPomodoroEntry.pauseDate = Date()
            viewContext.saveAndLogError()
            stopTimerAndCancelNotificationIfNeeded()
        }
    }
    
    func getExpectedStage() -> Int {
        let stage = focusAndBreakStage
        switch (timerType) {
        case .pomodoro:
            if (stage % 2 == 0) {
                return stage
            }
            return stage + 1
        case .shortBreak:
            let breakStage = stage / 2 % 4
            if (stage % 2 == 1) {
                if (breakStage < 3) {
                    return stage
                }
                return stage + 2
            }
            if (breakStage < 3) {
                return stage + 1
            }
            return stage + 3
        case .longBreak:
            let breakStage = stage / 2 % 4
            if (stage % 2 == 1) {
                if (breakStage < 3) {
                    return stage + 2 * (3 - breakStage)
                }
                return stage
            }
            if (breakStage < 3) {
                return stage + 1 + 2 * (3 - breakStage)
            }
            return stage + 1
        }
    }

    func updateRemaining() {
        guard let lastPomodoroEntry = relevantLastPomodoroEntryOrNil else {
            return
        }
        let newRemaining = lastPomodoroEntry.getRemaining()
        print("apom updateRemaining \(timerType) \(lastPomodoroEntry.timerType ?? "nil")")
        if (abs(newRemaining - Double(remaining - 1)) < 0.5) {
            remaining -= 1
        } else {
            remaining = max(0, Int32(Int(newRemaining)))
        }
    }
    
    func changeStageIfNeeded() {
        let expStage = getExpectedStage()
        if (expStage != focusAndBreakStage) {
            NSLog("currStage = \(focusAndBreakStage) expStage = \(expStage)")
            focusAndBreakStage = expStage
        }
    }
    
    func scheduleTimerAndNotificationIfNeeded() {
        if timer != nil {
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true)
        { t in
            updateRemaining()
            if (remaining <= 0) {
                goToNextStage()
                Timer.scheduledTimer(withTimeInterval: 1, repeats: false) {
                    t in
                    if (timer == nil) {
                        remaining = seconds
                    }
                }
            }
        }
        
        scheduleNotificationIfNeeded()
    }
    
    func scheduleNotificationIfNeeded() {
        if (remaining <= 1 || timer == nil) {
            return
        }
        #if os(iOS)
        let content = UNMutableNotificationContent()
        switch (timerType) {
        case .pomodoro:
            content.title = "Focus time over"
            content.body = "Time to take a break!"
        case .shortBreak, .longBreak:
            content.title = "Break over"
            content.body = "Time to focus!"
        }
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remaining), repeats: false)
        let request = UNNotificationRequest(identifier: timerType.rawValue, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        #else
        // TODO mac notification
        #endif
    
    }
    
    func stopTimerAndCancelNotificationIfNeeded() {
        if (timer == nil) {
            return
        }
        
        timer!.invalidate()
        timer = nil

        #if os(iOS)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerType.rawValue])
        #endif
    }
    
    func updateNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerType.rawValue])
        scheduleNotificationIfNeeded()
    }
    
    func goToNextStage() {
        print("apom goToNextStage in \(timerType)")
        focusAndBreakStage += 1
    }
}

struct TimerView_Previews: PreviewProvider {
    static var modelData = ModelData()
    static var lastPomodoroEntryBinder = LatestObjectBinder<PomodoroEntry>(
        container: PersistenceController.preview.persistentContainer,
        sortKey: "startDate")
    
    static var previews: some View {
        TimerView(25, timerType: .pomodoro)
        .previewDisplayName("SE portrait")
        .withPreviewEnvironment("iPhone SE (3rd generation)")

        TimerView(5, timerType: .shortBreak)
        .previewDisplayName("SE landscape")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .previewInterfaceOrientation(.landscapeLeft)
        
        TimerView(25, timerType: .pomodoro)
        .withPreviewEnvironment("iPhone 14 Pro Max")
        
        TimerView(25, timerType: .pomodoro)
        .withPreviewEnvironment("iPad (10th generation)")
    }
}
