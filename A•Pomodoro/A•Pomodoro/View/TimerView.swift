//
//  TimerView.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 16/12/2022.
//

import SwiftUI

struct TimerView: View {

    static let notificationIdentifier = "Pomodoro"
    static let multiplier: Int32 = 60
    
    @EnvironmentObject var modelData: ModelData
    var seconds: Int32
    var timerType: TimerType
    @State var timer: Timer? = nil
    @State var startDate: Date? = nil
    @State var pauseStartDate: Date? = nil
    @State var pauseDuration: TimeInterval = 0
    @AppStorage("focusAndBreakStage") private var focusAndBreakStage = 0

    // calculated
    @State var remaining: Int32

    init(_ minutes: Int32, timerType: TimerType) {
        seconds = minutes * TimerView.multiplier
        self.timerType = timerType
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(String(format: "%02d:%02d", (remaining / 60), remaining % 60))
            .font(.system(size: 80).monospacedDigit())
            .padding(EdgeInsets(top: 0, leading: 56, bottom: 0, trailing: 56))
            if (timer == nil) {
                Button {
                    if (pauseStartDate == nil) {
                        startDate = Date()
                        pauseDuration = 0
                        remaining = seconds - 1
                    } else {
                        let duration = -pauseStartDate!.timeIntervalSinceNow
                        pauseDuration += duration
                        pauseStartDate = nil
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) {
                            t in
                            updateRemaining()
                        }
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
                        startDate = nil
                        pauseStartDate = nil
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
                        pauseStartDate = Date()
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
                pauseDuration = 0
                pauseStartDate = nil
                if (timer == nil) {
                    return
                }
                startDate = nil
                timer?.invalidate()
                timer = nil
            }
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
        let elapsed = -startDate!.timeIntervalSinceNow - pauseDuration
        let newRemaining = Double(seconds) - elapsed
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
