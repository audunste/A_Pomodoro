//
//  Sparkle.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 01/01/2023.
//

import Foundation

struct Sparkle: Hashable {
    let x: Double
    let y: Double
    let scale: Double
    let creationDate = Date.now.timeIntervalSinceReferenceDate
}
