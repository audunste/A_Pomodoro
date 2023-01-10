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

class IdentifiableGroup<I, T>: Identifiable, Hashable where I: Hashable {
    
    let id: I
    var items: [T] = []
    
    init(id: I) {
        self.id = id
    }
    
    func append(_ item: T) {
        items.append(item)
    }
    
    // TODO unsure if it's a good idea to do hashing and equality only based on the id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: IdentifiableGroup<I, T>, rhs: IdentifiableGroup<I, T>) -> Bool {
        return lhs.id == rhs.id
    }

}
