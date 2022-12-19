//
//  ContentView.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 11/12/2022.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var modelData: ModelData
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: Tab = .pomodoro
    
    enum Tab {
        case pomodoro
        case shortBreak
        case longBreak
    }
    
    var body: some View {
        VStack {
            TabView(selection: $selection) {
                TimerView(25, isFocus: true)
                    .tag(Tab.pomodoro)
                TimerView(5, isFocus: false)
                    .tag(Tab.shortBreak)
                TimerView(15, isFocus: false)
                    .tag(Tab.longBreak)
            }
            .foregroundColor(.white)
            .tabViewStyle(.page)
            HStack {
                Button {
                    selection = .pomodoro
                } label: {
                    Text("Pomodoro")
                    .padding(.bottom, 4)
                    .padding(.top, 4)
                }
                .tint(modelData.appColor.accentColor)
                .foregroundColor(.white)
                .buttonStyleFor(selected: selection == .pomodoro)
                .contentShape(Rectangle())
                Button {
                    selection = .shortBreak
                } label: {
                    Text("Short Break")
                    .padding(.bottom, 4)
                    .padding(.top, 4)
                }
                .tint(modelData.appColor.accentColor)
                .foregroundColor(.white)
                .buttonStyleFor(selected: selection == .shortBreak)
                .contentShape(Rectangle())
                Button {
                    selection = .longBreak
                } label: {
                    Text("Long Break")
                    .padding(.bottom, 4)
                    .padding(.top, 4)
                }
                .tint(modelData.appColor.accentColor)
                .foregroundColor(.white)
                .buttonStyleFor(selected: selection == .longBreak)
                .contentShape(Rectangle())
            }
            .padding(.bottom, 0)
        }
        .background(modelData.appColor.backgroundColor)
        .onChange(of: selection) { newSelection in
            updateAppColors(newSelection)
        }
        .onAppear() {
            updateAppColors(selection)
        }
    }
    
    // This function is required to get the system color scheme
    func getSystemColorScheme() -> ColorScheme {
        return UITraitCollection.current.userInterfaceStyle == .light ? .light : .dark
    }

    func updateAppColors(_ newSelection: Tab) {
        let scheme = getSystemColorScheme()
        withAnimation(.easeInOut(duration: 0.2)) {
            switch (scheme) {
            case .dark:
                switch (newSelection) {
                case .pomodoro:
                    modelData.appColor = .pomodoroDark
                case .shortBreak:
                    modelData.appColor = .shortBreakDark
                case .longBreak:
                    modelData.appColor = .longBreakDark
                }
                break
            case .light, _:
                switch (newSelection) {
                case .pomodoro:
                    modelData.appColor = .pomodoroLight
                case .shortBreak:
                    modelData.appColor = .shortBreakLight
                case .longBreak:
                    modelData.appColor = .longBreakLight
                }
                break
            }
        }
    }
}

extension View {
    @ViewBuilder
    func buttonStyleFor(selected: Bool) -> some View {
        if (selected) {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ModelData())
    }
}
