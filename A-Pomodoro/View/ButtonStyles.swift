//
//  ButtonStyles.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 28/12/2022.
//

import SwiftUI

struct UnstyledButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}

struct NormalButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(Color(white: 1.0, opacity: 0.07))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct IconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(Color(white: 1.0, opacity: 0.07))
            .clipShape(Circle())
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

struct NavButton: ButtonStyle {
    @EnvironmentObject var modelData: ModelData
    @Environment(\.mainWindowSize) var mainWindowSize
    let isSelected: Bool

    init(_ isSelected: Bool) {
        self.isSelected = isSelected
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: mainWindowSize.width < 390 ? 14 : 16))
            .padding(.bottom, 10)
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
            .foregroundColor(modelData.appColor.textColor)
            .background(Color(white: isSelected ? 0.0 : 1.0, opacity: 0.07))
            .clipShape(Capsule())
            .contentShape(Rectangle())
    }
}
