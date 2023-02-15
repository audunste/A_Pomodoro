//
//  SettingsView.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 14/02/2023.
//

import SwiftUI

enum Settings: String {
    case main
    case secret
}

struct SettingsView: View {

    #if os(macOS)
    let showFooter = true
    #else
    let showFooter = false
    #endif
    
    @Environment(\.dismiss) var dismiss
    @State private var presentedSettings: [Settings] = []

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $presentedSettings) {
                MainSettings(presentedSettings: $presentedSettings)
                .navigationDestination(for: Settings.self) { settings in
                    switch settings {
                    case .secret:
                        SecretSettings()
                            .navigationBarBackButtonHidden()
                            .transition(.move(edge: .trailing))
                    default:
                        Spacer()
                    }
                }
            }
            .tint(Color("BarText"))
            .background(Color("BarBackground"))
            .environment(\.up, {
                withAnimation(.easeInOut(duration: 0.175)) {
                    _ = presentedSettings.popLast()
                }
            })
            
            if showFooter {
                SheetBottomBar()
            }
        }
    }
}

struct MainSettings: View {
    @Binding var presentedSettings: [Settings]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                SettingsHeader(presentedSettings: $presentedSettings)
                .fixedSize(horizontal: false, vertical: true)
                SettingsBody()
                .frame(maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct SecretSettings: View {
    @Environment(\.up) var up

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    Button {
                        up?()
                    } label: {
                        Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                        .padding(16)
                    }
                    .buttonStyle(.borderless)
                    .contentShape(Rectangle())
                    
                    Spacer()
                    
                    Text("Secret Settings")
                    .font(.regularTitle)
                    .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    
                    Spacer()
                    
                    Spacer()
                        .frame(width: 24, height: 24)
                        .padding(16)
                }
                .frame(maxWidth: .infinity)
                .background(Color("BarBackground"))
                .foregroundColor(Color("BarText"))
                .fixedSize(horizontal: false, vertical: true)
                
                SecretSettingsBody()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct SettingsHeader: View {
    @Binding var presentedSettings: [Settings]
    @State var ssCount1: Int = 0
    @State var ssCount2: Int = 0

    var body: some View {
        HStack {
            Button {
                if ssCount1 >= 3 && ssCount2 == 2 {
                    ALog("Trigger SS")
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.175)) {
                            presentedSettings.append(.secret)
                        }
                    }
                    ssCount1 = 0
                    ssCount2 = 0
                } else {
                    ssCount1 += 1
                    ssCount2 = 0
                }
            } label: {
                Color(white: 1.0, opacity: 0.00001)
            }
            .buttonStyle(.borderless)
            
            Text("Settings")
            .font(.regularTitle)
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            Button {
                ssCount2 += 1
                if ssCount2 > 2 {
                    ssCount1 = 0
                }
            } label: {
                Color(white: 1.0, opacity: 0.0001)
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity)
        .background(Color("BarBackground"))
        .foregroundColor(Color("BarText"))
    }
}

struct SettingsBody: View {
    var body: some View {
        ScrollView {
            VStack {
                Button {
                    
                } label: {
                    HStack {
                        Text("Settings")
                        .font(.regularBody)
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .background(Color("Background"))
        .foregroundColor(Color("PrimaryText"))
    }
}

struct SettingsFooter: View {
    var body: some View {
        HStack {
            Color.red
        }
        .background(Color("BarBackground"))
        .foregroundColor(Color("BarText"))
    }
}

struct SecretSettingsBody: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button {
                    PersistenceController.active.deleteReciprocateObjects()
                } label: {
                    HStack {
                        Text("Delete Reciprocate objects")
                        .font(.regularBody)
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                
                Divider()
                
                Button {
                    PersistenceController.active.logShareParticipants()
                } label: {
                    HStack {
                        Text("Log History share participants")
                        .font(.regularBody)
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                
                Button {
                    PersistenceController.active.unshareOwnHistory()
                } label: {
                    HStack {
                        Text("Unshare own history")
                        .font(.regularBody)
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                
                Spacer()
            }
        }
        .background(Color("Background"))
        .foregroundColor(Color("PrimaryText"))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
        
        SecretSettings()
        .previewDisplayName("Secret")
    }
}
