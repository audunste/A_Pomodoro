//
//  ContentView.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 11/12/2022.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var modelData: ModelData
    @EnvironmentObject var lastPomodoroEntryBinder: LatestObjectBinder<PomodoroEntry>
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: TimerType = .pomodoro
    @AppStorage("focusAndBreakStage") private var focusAndBreakStage = -1
    @AppStorage("lastStageChangeTimestamp") private var lastStageChangeTimestamp = Date().timeIntervalSince1970
        
    var body: some View {
        GeometryReader { geometry in
            VStack {
                TabView(selection: $selection) {
                    TimerView(25, timerType: .pomodoro)
                        .tabItem {
                            Text("Pomodoro")
                        }
                        .tag(TimerType.pomodoro)
                    TimerView(5, timerType: .shortBreak)
                        .tabItem {
                            Text("Short break")
                        }
                        .tag(TimerType.shortBreak)
                    TimerView(15, timerType: .longBreak)
                        .tabItem {
                            Text("Long break")
                        }
                        .tag(TimerType.longBreak)
                }
                .foregroundColor(modelData.appColor.textColor)
                #if os(iOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                #else
                .tabViewStyle(.automatic)
                #endif
                #if os(iOS)
                HStack {
                    Button {
                        selection = .pomodoro
                    } label: {
                        Text("Pomodoro")
                        .padding(.bottom, 4)
                        .padding(.top, 4)
                    }
                    .tint(modelData.appColor.accentColor)
                    .foregroundColor(modelData.appColor.textColor)
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
                    .foregroundColor(modelData.appColor.textColor)
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
                    .foregroundColor(modelData.appColor.textColor)
                    .buttonStyleFor(selected: selection == .longBreak)
                    .contentShape(Rectangle())
                }
                .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 8)
                #endif
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
                    focusAndBreakStage = -1
                } else {
                    print("apom man obj = \(String(describing: lastPomodoroEntryBinder.managedObject))")
                    if let entry = lastPomodoroEntryBinder.managedObject {
                        print("apom setting focusAndBreakStage to \(entry.stage)")
                        focusAndBreakStage = Int(entry.stage)
                        updateSelection(stage: focusAndBreakStage)
                    }
                }
            }
            .onChange(of: focusAndBreakStage) {
                stage in
                updateSelection(stage: stage)
            }
        }
    }
    
    func updateSelection(stage: Int) {
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
    
    // This function is required to get the system color scheme
    func getSystemColorScheme() -> ColorScheme {
        #if os(iOS)
        return UITraitCollection.current.userInterfaceStyle == .light ? .light : .dark
        #else
        let ea = NSApp.effectiveAppearance
        let best = ea.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua
        switch best {
        case .darkAqua:
            return .dark
        default:
            return .light
        }
        #endif
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
            buttonStyle(SelectedButton())
        } else {
            buttonStyle(NormalButton())
        }
    }
}

struct PreviewModifier: ViewModifier {
    let device: String
    var modelData = ModelData()
    var lastPomodoroEntryBinder = LatestObjectBinder<PomodoroEntry>(
        container: PersistenceController.preview.persistentContainer,
        sortKey: "startDate")
        
    func body(content: Content) -> some View {
        content
        .environmentObject(modelData)
        .environmentObject(lastPomodoroEntryBinder)
        .background(modelData.appColor.backgroundColor)
        .foregroundColor(modelData.appColor.textColor)
        .previewDevice(PreviewDevice(rawValue: device))
        .previewDisplayName(device)
    }
}

extension View {
    func withPreviewEnvironment(_ device: String) -> some View {
        self.modifier(PreviewModifier(device: device))
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
        .previewDisplayName("SE portrait")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        
        ContentView()
        .previewDisplayName("SE landscape")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .previewInterfaceOrientation(.landscapeLeft)
        
        ContentView()
        .withPreviewEnvironment("iPhone 14 Pro Max")
        
        ContentView()
        .withPreviewEnvironment("iPad (10th generation)")
    }
}

