//
//  ContentStyle.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 17/12/2022.
//

import SwiftUI

class ContentStyle: ObservableObject {
    @Published var backgroundColor: Color;
    @Published var backgroundTone1: Color;
    @Published var backgroundTone2: Color;
    @Published var accentColor: Color;
    
    init() {
        backgroundColor = Color(hue: 0.03, saturation: 0.6, brightness: 0.5)
        backgroundTone1 = Color(hue: 0.03, saturation: 0.6, brightness: 0.6)
        backgroundTone2 = Color(hue: 0.03, saturation: 0.6, brightness: 0.4)
        accentColor = Color(hue: 0.11, saturation: 0.6, brightness: 1.0)
    }
}
