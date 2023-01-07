//
//  MiscUtil.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 01/01/2023.
//

import Foundation

public extension Double {

    /// Returns a random floating point number between 0.0 and 1.0, inclusive.
    static var random: Double {
        return Double(arc4random()) / 0xFFFFFFFF
    }

    static func random(min: Double, max: Double) -> Double {
        return Double.random * (max - min) + min
    }
}

class IdentifiableGroup<I, T>: Identifiable where I: Hashable {
    let id: I
    var items: [T] = []
    
    init(id: I) {
        self.id = id
    }
    
    func append(_ item: T) {
        items.append(item)
    }
}
