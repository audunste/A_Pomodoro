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
    @State private var selection: TimerType = .pomodoro
    @AppStorage("focusAndBreakStage") private var focusAndBreakStage = 0
    @AppStorage("lastStageChangeTimestamp") private var lastStageChangeTimestamp = Date().timeIntervalSince1970
        
    var body: some View {
        GeometryReader { geometry in
            VStack {
                TabView(selection: $selection) {
                    TimerView(25, timerType: .pomodoro)
                        .tag(TimerType.pomodoro)
                    TimerView(5, timerType: .shortBreak)
                        .tag(TimerType.shortBreak)
                    TimerView(15, timerType: .longBreak)
                        .tag(TimerType.longBreak)
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
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 8)
            }
            .background(modelData.appColor.backgroundColor)
            .onChange(of: selection) { newSelection in
                updateAppColors(newSelection)
            }
            .onAppear() {
                updateAppColors(selection)
                let timeSinceStageChange = Date().timeIntervalSince1970 - lastStageChangeTimestamp
                if (timeSinceStageChange > 60 * 45) {
                    NSLog("Resetting stage because long time since last stage change")
                    focusAndBreakStage = 0
                }
            }
            .onChange(of: focusAndBreakStage) {
                stage in
                print("apom stage onChange to = \(stage)")
                if (stage % 2 == 0) {
                    selection = .pomodoro
                } else {
                    switch (stage / 2 % 4) {
                    case 0...2:
                        selection = .shortBreak
                    case 3, _:
                        selection = .longBreak
                    }
                }
        }
        }
    }
    
    // This function is required to get the system color scheme
    func getSystemColorScheme() -> ColorScheme {
        return UITraitCollection.current.userInterfaceStyle == .light ? .light : .dark
    }

    func updateAppColors(_ newSelection: TimerType) {
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
