//
//  ALog.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 17/01/2023.
//

import Foundation


enum LogLevel: String {
    case debug
    case info
    case warning
    case error
}

func ALog(level: LogLevel = .debug, tag: String = "apom", context: String = #function, _ msg: String = "") {
    ALogClass.shared.log(level: level, tag: tag, context: context, msg: msg)
}

class ALogClass {
    static let shared: ALogClass = ALogClass()
    
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM dd HH:mm:ss"
        df.locale = Locale(identifier: "en-US")
        return df
    }()
    
    
    func log(level: LogLevel, tag: String, context: String, msg: String) {
        synchronized(self) {
            let logStr = [date, tag, msg].joined(separator: " ")
            let paddedStr = logStr.count < 80 ? logStr.padding(toLength: 80, withPad: " ", startingAt: 0) : logStr
            print(paddedStr, context, separator: " ")
        }
    }
    
    private var date: String {
        return Self.dateFormatter.string(from: Date())
    }
}
