//
//  ProgressText.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 27/12/2022.
//

import SwiftUI

struct ProgressText: View {
    let remaining: Int32
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text(String(format: "%02d:%02d", (remaining / 60), remaining % 60))
                .font(.system(size: round(0.19 * geometry.size.width)).monospacedDigit())
                .shadow(radius: 3, y: 1)
                .padding(0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct ProgressText_Previews: PreviewProvider {
    static var previews: some View {
        ProgressText(remaining: 25 * 60)
        .border(.gray)
    }
}
