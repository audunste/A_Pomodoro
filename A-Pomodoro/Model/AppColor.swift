//
//  AppColor.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 18/12/2022.
//

import SwiftUI

struct AppColor {
    var backgroundColor: Color
    var accentColor: Color
    var accentColor2: Color
    var textColor: Color
    
    init(hue: Double, saturation: Double, b1: Double, b2: Double,
        textWhite: Double = 1.0)
    {
        self.backgroundColor = Color(hue: hue, saturation: saturation, brightness: b1)
        self.accentColor = Color(hue: hue, saturation: saturation, brightness: b2)
        self.accentColor2 = Color(hue: hue, saturation: saturation, brightness: 0.5 * (b1 + b2))
        self.textColor = Color(white: textWhite)
    }
    
    static let pomodoroLight = AppColor(
        hue: 0.01, saturation: 0.64, b1: 0.74, b2: 0.94)
    
    static let pomodoroDark = AppColor(
        hue: 0.01, saturation: 0.64, b1: 0.64, b2: 0.84, textWhite: 0.95)

    static let shortBreakLight = AppColor(
        hue: 0.32, saturation: 0.60, b1: 0.54, b2: 0.74)

    static let shortBreakDark = AppColor(
        hue: 0.32, saturation: 0.60, b1: 0.46, b2: 0.66, textWhite: 0.95)

    static let longBreakLight = AppColor(
        hue: 0.58, saturation: 0.67, b1: 0.58, b2: 0.78)

    static let longBreakDark = AppColor(
        hue: 0.58, saturation: 0.67, b1: 0.48, b2: 0.68, textWhite: 0.95)

}
