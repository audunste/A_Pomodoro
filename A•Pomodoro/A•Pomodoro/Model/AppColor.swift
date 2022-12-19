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
    var textColor: Color
    
    init(_ backgroundColor: Color, _ accentColor: Color, textColor: Color = .white) {
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.textColor = textColor
    }
    
    static let pomodoroLight = AppColor(
        Color(hue: 0.03, saturation: 0.72, brightness: 0.8),
        Color(hue: 0.03, saturation: 0.72, brightness: 1.0))
    
    static let pomodoroDark = AppColor(
        Color(hue: 0.03, saturation: 0.72, brightness: 0.7),
        Color(hue: 0.03, saturation: 0.72, brightness: 0.9),
        textColor: Color(white: 0.95))

    static let shortBreakLight = AppColor(
        Color(hue: 0.32, saturation: 0.65, brightness: 0.54),
        Color(hue: 0.32, saturation: 0.65, brightness: 0.74))

    static let shortBreakDark = AppColor(
        Color(hue: 0.32, saturation: 0.65, brightness: 0.46),
        Color(hue: 0.32, saturation: 0.65, brightness: 0.66),
        textColor: Color(white: 0.95))

    static let longBreakLight = AppColor(
        Color(hue: 0.58, saturation: 0.67, brightness: 0.58),
        Color(hue: 0.58, saturation: 0.67, brightness: 0.78))

    static let longBreakDark = AppColor(
        Color(hue: 0.58, saturation: 0.67, brightness: 0.48),
        Color(hue: 0.58, saturation: 0.67, brightness: 0.68),
        textColor: Color(white: 0.95))

}
