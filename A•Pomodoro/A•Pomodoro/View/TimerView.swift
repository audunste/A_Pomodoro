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
    var isFocus: Bool
    @State var timer: Timer? = nil
    @State var remaining: Int32
    @State var startDate: Date? = nil

    init(_ minutes: Int32, isFocus: Bool) {
        seconds = minutes * TimerView.multiplier
        self.isFocus = isFocus
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack {
            Text(String(format: "%02d:%02d", (remaining / 60), remaining % 60))
            .font(.system(size: 60).monospacedDigit())
            if (timer == nil) {
                Button {
                    startDate = Date()
                    remaining = seconds - 1
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true)
                    { t in
                        updateRemaining()
                        if (remaining <= 0) {
                            t.invalidate()
                            timer = nil
                        }
                    }
                    scheduleNotification()
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .tint(modelData.appColor.accentColor)
                .foregroundColor(.white)
                .buttonStyle(.borderedProminent)
                .font(.system(size: 30))
            } else {
                Button {
                    timer!.invalidate()
                    timer = nil
                    remaining = seconds
                    cancelNotification()
                } label: {
                    Text("Stop")
                        .frame(maxWidth: .infinity)
                }
                .tint(modelData.appColor.accentColor)
                .foregroundColor(.white)
                .buttonStyle(.borderedProminent)
                .font(.system(size: 30))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    func updateRemaining() {
        let elapsed = -startDate!.timeIntervalSinceNow
        remaining = max(0, Int32(Int(Double(seconds) - elapsed)))
    }
    
    func scheduleNotification() {
        let content = UNMutableNotificationContent()
        if (isFocus) {
            content.title = "Focus time over"
            content.body = "Time to take a break!"
        } else {
            content.title = "Break over"
            content.body = "Time to focus!"
        }
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: TimerView.notificationIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

struct TimerView_Previews: PreviewProvider {
    static var modelData = ModelData()
    
    static var previews: some View {
        TimerView(25, isFocus: true)
            .environmentObject(modelData)
            .background(modelData.appColor.backgroundColor)
            .foregroundColor(.white)
    }
}
