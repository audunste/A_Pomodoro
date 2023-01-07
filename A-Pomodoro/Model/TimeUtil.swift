//
//  TimeUtil.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 06/01/2023.
//

import Foundation


extension TimeInterval {
    static let minute: TimeInterval = 60.0
    static let hour: TimeInterval = minute * 60.0
    static let day: TimeInterval = hour * 24.0
}


typealias ADay = Int32

extension ADay {
    static func of(date: Date) -> ADay {
        let timeInterval = date.timeIntervalSinceReferenceDate
        let dayFloat = timeInterval / TimeInterval.day
        return Int32(dayFloat)
    }
    
    static var today: ADay {
        Self.of(date: Date())
    }
    
    var date: Date {
        Date(timeIntervalSinceReferenceDate: TimeInterval(Double(self) * TimeInterval.day))
    }
}
