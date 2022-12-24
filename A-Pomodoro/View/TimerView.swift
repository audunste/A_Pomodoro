//
//  TimerView.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 16/12/2022.
//

import SwiftUI
import CoreData

struct TimerView: View {

    static let notificationIdentifier = "Pomodoro"
    static let multiplier: Int32 = 60
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var lastPomodoroEntryBinder = LatestObjectBinder<PomodoroEntry>(
        container: PersistenceController.shared.persistentContainer,
        sortKey: "startDate")
    @EnvironmentObject var modelData: ModelData
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
    
    private var lastPomodoroEntry: PomodoroEntry? {
        lastPomodoroEntryBinder.managedObject
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            if let lastPomodoroEntry = lastPomodoroEntryBinder.managedObject {
                Text("Has pomodoro entry \(lastPomodoroEntry.timerType!)")
            }
            Text(String(format: "%02d:%02d", (remaining / 60), remaining % 60))
            .font(.system(size: 80).monospacedDigit())
            .padding(EdgeInsets(top: 0, leading: 56, bottom: 0, trailing: 56))
            if (timer == nil) {
                Button {
                    if (lastPomodoroEntry?.isPaused ?? false) {
                        let duration = -lastPomodoroEntry!.pauseDate!.timeIntervalSinceNow
                        lastPomodoroEntry!.pauseSeconds += duration
                        lastPomodoroEntry!.pauseDate = nil
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
                        remaining = seconds - 1
                    }
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true)
                    { t in
                        updateRemaining()
                        if (remaining <= 0) {
                            finish()
                            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) {
                                t in
                                if (timer == nil) {
                                    remaining = seconds
                                }
                            }
                        }
                    }
                    scheduleNotification()
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
                        timer!.invalidate()
                        timer = nil
                        if let entry = lastPomodoroEntry {
                            if entry.stage == focusAndBreakStage {
                                viewContext.delete(entry)
                                viewContext.saveAndLogError()
                            }
                        }
                        remaining = seconds
                        cancelNotification()
                    } label: {
                        Image(systemName: "backward.end")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(12)
                            .colorMultiply(modelData.appColor.textColor)
                    }
                    Button {
                        if let entry = lastPomodoroEntry {
                            entry.pauseDate = Date()
                            viewContext.saveAndLogError()
                        }
                        timer!.invalidate()
                        timer = nil
                        cancelNotification()
                    } label: {
                        Text("Pause")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(modelData.appColor.accentColor)
                    .foregroundColor(.white)
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 30))
                    Button {
                        cancelNotification()
                        remaining = seconds
                        finish()
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
                if (timer == nil) {
                    return
                }
                timer?.invalidate()
                timer = nil
            }
        }
        .onChange(of: lastPomodoroEntryBinder.managedObject) {
            object in
            print("Received onChange")
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
        let newRemaining = lastPomodoroEntry?.getRemaining() ?? Double(seconds)
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
    
    func scheduleNotification() {
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
        let request = UNNotificationRequest(identifier: TimerView.notificationIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func finish() {
        NSLog("finish in \(timerType)")
        focusAndBreakStage += 1
    }
}

struct TimerView_Previews: PreviewProvider {
    static var modelData = ModelData()
    
    static var previews: some View {
        TimerView(25, timerType: .pomodoro)
            .environmentObject(modelData)
            .background(modelData.appColor.backgroundColor)
            .foregroundColor(.white)
    }
}
