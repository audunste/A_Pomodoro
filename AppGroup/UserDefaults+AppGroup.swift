//
//  UserDefaults+AppGroup.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 02/03/2023.
//

import Foundation

extension UserDefaults {
    static var group: UserDefaults {
        return UserDefaults(suiteName: "group.no.steinholm.A-Pomodoro")!
    }
}

enum AppGroupKey {
    enum Timer {
        static let endDate = "timer.endDate"
        static let seconds = "timer.seconds"
        static let isFocusType = "timer.isFocusType"
    }
}

enum WidgetKind {
    static let remaining = "no.steinholm.A-Pomodoro.Remaining"
}
