//
//  SquareZStack.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 26/12/2022.
//

import SwiftUI

struct SquareZStack<Content: View>: View {
    var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack(content: content)
            .frame(width: size, height: size)
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
}
