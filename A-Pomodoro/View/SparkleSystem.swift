//
//  SparkleSystem.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 01/01/2023.
//

import SwiftUI

class SparkleSystem {
    let image = Image("Sparkle2")
    var particles = Set<Sparkle>()
    var center = UnitPoint.center
    var radius = 0.0

    private func addSparkle(baseAngle: Double) {
        let angleRad = baseAngle + Double.random(min: 0.0, max: 0.25 * .pi)
        let radius = radius * Double.random(min: 0.95, max: 1.05)
        let spx = cos(angleRad) * radius
        let spy = sin(angleRad) * radius
        let newSparkle1 = Sparkle(x: center.x + spx, y: center.y + spy, scale: Double.random(min: 0.15, max: 0.3))
        particles.insert(newSparkle1)
        let newSparkle2 = Sparkle(x: center.x + spx, y: center.y + spy, scale: Double.random(min: 0.15, max: 0.3))
        particles.insert(newSparkle2)
    }

    func update(date: TimeInterval, sparklesOn: Bool) {
        let deathDate = date - 2

        for particle in particles {
            if particle.creationDate < deathDate {
                particles.remove(particle)
            }
        }

        if (sparklesOn) {
            addSparkle(baseAngle: Double(date) * 12 + 4 * .pi / 3)
            addSparkle(baseAngle: Double(date) * 12 + 2 * .pi / 3)
            addSparkle(baseAngle: Double(date) * 12)
        }
    }
}
