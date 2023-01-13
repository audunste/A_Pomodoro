//
//  ContentView.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 11/12/2022.
//

import SwiftUI

enum SheetType: String {
    case none
    case history
}

extension GeometryProxy {
    var navButtonWidth: CGFloat {
        (min(430, size.width) - 48) / 3
    }
}

struct ContentView: View {

    @EnvironmentObject var modelData: ModelData
    @EnvironmentObject var lastPomodoroEntryBinder: LatestObjectBinder<PomodoroEntry>
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: TimerType = .pomodoro
    @State private var sheet: SheetType = .none
    @AppStorage("focusAndBreakStage") private var focusAndBreakStage = -1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                    HStack(spacing: 8) {
                        Spacer()
                            .frame(width: 8)
                        Button {
                            selection = .pomodoro
                        } label: {
                            Text("Pomodoro")
                        }
                        .buttonStyle(NavButton(selection == .pomodoro))
                        .frame(width: geometry.navButtonWidth)
                        Button {
                            selection = .shortBreak
                        } label: {
                            Text(NSLocalizedString("Short break", comment: "Name of short break timer"))
                        }
                        .buttonStyle(NavButton(selection == .shortBreak))
                        .frame(width: geometry.navButtonWidth)
                        Button {
                            selection = .longBreak
                        } label: {
                            Text(NSLocalizedString("Long break", comment: "Name of long break timer"))
                        }
                        .buttonStyle(NavButton(selection == .longBreak))
                        .frame(width: geometry.navButtonWidth)
                        Spacer()
                            .frame(width: 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 8)
                    .fixedSize(horizontal: false, vertical: false)
                    #endif
                }
                .background(modelData.appColor.backgroundColor)
                .onChange(of: selection) { newSelection in
                    updateAppColors(newSelection)
                }
                .onAppear() {
                    print("apom man obj = \(String(describing: lastPomodoroEntryBinder.managedObject))")
                    if let entry = lastPomodoroEntryBinder.managedObject {
                        print("apom setting focusAndBreakStage to \(entry.stage)")
                        focusAndBreakStage = Int(entry.stage)
                        updateSelection(stage: focusAndBreakStage)
                    }
                    updateAppColors(selection)
                }
                .onChange(of: focusAndBreakStage) {
                    stage in
                    updateSelection(stage: stage)
                }
            }
            HStack {
                Spacer()
                Button {
                    sheet = .history
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(IconButton())
                Spacer()
                .frame(width: 16)
            }
            .frame(height: 56)
        }
        .sheet(isPresented: isSheetPresented) {
            switch sheet {
            case .history:
                #if os(macOS)
                HistoryView()
                .frame(width: 400, height: 600)
                #else
                HistoryView()
                #endif
            default:
                Text("No sheet")
            }
        }
    }
    
    var isSheetPresented: Binding<Bool> {
        Binding {
            return sheet != .none
        }
        set: {
            newValue in
            if !newValue {
                sheet = .none
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
        GeometryReader() { geometry in
            ContentView()
            .environment(\.mainWindowSize, geometry.size)
        }
        .previewDisplayName("SE portrait")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        
        GeometryReader() { geometry in
            ContentView()
            .environment(\.mainWindowSize, geometry.size)
        }
        .previewDisplayName("SE landscape")
        .withPreviewEnvironment("iPhone SE (3rd generation)")
        .previewInterfaceOrientation(.landscapeLeft)
        
        GeometryReader() { geometry in
            ContentView()
            .environment(\.mainWindowSize, geometry.size)
        }
        .withPreviewEnvironment("iPhone 14 Pro Max")
        
        GeometryReader() { geometry in
            ContentView()
            .environment(\.mainWindowSize, geometry.size)
        }
        .withPreviewEnvironment("iPad (10th generation)")
    }
}

