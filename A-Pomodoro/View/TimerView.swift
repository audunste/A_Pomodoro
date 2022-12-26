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

    init(_ minutes: Int32, timerType: TimerType) {
        seconds = minutes * TimerView.multiplier
        self.timerType = timerType
        _remaining = State(initialValue: seconds)
    }
    
    private var lastPomodoroEntry: PomodoroEntry {
        lastPomodoroEntryBinder.managedObject ?? PomodoroEntry()
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(String(format: "%02d:%02d", (remaining / 60), remaining % 60))
            .font(.system(size: 80).monospacedDigit())
            .padding(EdgeInsets(top: 0, leading: 56, bottom: 0, trailing: 56))
            if (timer == nil) {
                Button {
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
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .tint(modelData.appColor.accentColor)
                .foregroundColor(.white)
                .buttonStyle(.borderedProminent)
                .font(.system(size: 30))
                .padding(EdgeInsets(top: 0, leading: 56, bottom: 0, trailing: 56))
            } else {
                HStack {
                    Button {
                        stopTimerAndCancelNotificationIfNeeded()
                        lastPomodoroEntry.pauseDate = Date()
                        lastPomodoroEntry.adjustmentSeconds += Double(seconds) - lastPomodoroEntry.getRemaining()
                        viewContext.saveAndLogError()
                        updateRemaining()
                    } label: {
                        Image(systemName: "backward.end")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(12)
                            .colorMultiply(modelData.appColor.textColor)
                    }
                    Button {
                        lastPomodoroEntry.pauseDate = Date()
                        viewContext.saveAndLogError()
                        stopTimerAndCancelNotificationIfNeeded()
                    } label: {
                        Text("Pause")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(modelData.appColor.accentColor)
                    .foregroundColor(.white)
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 30))
                    Button {
                        lastPomodoroEntry.fastForwardDate = Date()
                        viewContext.saveAndLogError()
                        stopTimerAndCancelNotificationIfNeeded()
                        remaining = seconds
                        goToNextStage()
                    } label: {
                        Image(systemName: "forward.end")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(12)
                            .colorMultiply(modelData.appColor.textColor)
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: focusAndBreakStage) {
            stage in
            if (getExpectedStage() != stage) {
                remaining = seconds
                stopTimerAndCancelNotificationIfNeeded()
            }
        }
        .onChange(of: lastPomodoroEntry) {
            entry in
            guard isThisViewRelevantForLastPomodoroEntry else {
                return
            }
            print("apom lastPomodoroEntry onChange \(lastPomodoroEntry.timerType!)")
            if focusAndBreakStage != entry.stage {
                print("apom setStage \(entry.stage), was \(focusAndBreakStage)")
                focusAndBreakStage = Int(entry.stage)
            }
            if !entry.isRunning {
                return
            }
            scheduleTimerAndNotificationIfNeeded()
        }
        .onChange(of: lastPomodoroEntry.fastForwardDate) {
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
        .onChange(of: lastPomodoroEntry.pauseDate) {
            date in
            guard isThisViewRelevantForLastPomodoroEntry else {
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
    }
    
    var isThisViewRelevantForLastPomodoroEntry: Bool {
        lastPomodoroEntry.timerType ?? "nil" == timerType.rawValue
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
    }
    
    func stopTimerAndCancelNotificationIfNeeded() {
        if (timer == nil) {
            return
        }
        
        timer!.invalidate()
        timer = nil

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerType.rawValue])
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
            .environmentObject(modelData)
            .environmentObject(lastPomodoroEntryBinder)
            .background(modelData.appColor.backgroundColor)
            .foregroundColor(.white)
    }
}
