//
//  ButtonStyles.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 28/12/2022.
//

import SwiftUI

struct NormalButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(Color(white: 1.0, opacity: 0.07))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct ProminentButton: ButtonStyle {
    @EnvironmentObject var modelData: ModelData

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(modelData.appColor.accentColor2)
            .clipShape(Capsule())
            .shadow(radius: 3, y: 1)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct SelectedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(Color(white: 0.0, opacity: 0.07))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 0.9)
    }
}
