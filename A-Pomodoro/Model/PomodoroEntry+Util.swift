//
//  PomodoroEntry+Util.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 24/12/2022.
//

import Foundation

extension PomodoroEntry {

    func getRemaining(at date: Date = Date()) -> Double {
        guard let startDate = self.startDate else {
            return 0
        }
        let stopDate = self.pauseDate ?? date
        let elapsed = -startDate.timeIntervalSince(stopDate) - self.pauseSeconds
        return max(0.0, self.timeSeconds - elapsed)
    }
    
    var isPaused: Bool {
        if self.pauseDate == nil {
            return false
        }
        if self.startDate == nil {
            return false
        }
        return getRemaining() > 0
    }
    
    var isRunning: Bool {
        if self.startDate == nil {
            return false
        }
        if self.isPaused {
            return false
        }
        if self.fastForwardDate != nil {
            return false
        }
        return getRemaining() > 0
    }
}
