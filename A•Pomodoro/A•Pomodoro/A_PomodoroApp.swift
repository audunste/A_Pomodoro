//
//  A_PomodoroApp.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 11/12/2022.
//

import SwiftUI
import UserNotifications

@main
struct A_PomodoroApp: App {
    @StateObject private var modelData = ModelData()
    
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        { success, error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelData)
                .preferredColorScheme(.dark)
        }
    }
}
