//
//  ContentView.swift
//  A•Pomodoro
//
//  Created by Audun Steinholm on 11/12/2022.
//

import SwiftUI

struct ContentView: View {

    @State private var selectedTab = 1
    
    var body: some View {
        VStack {
            HStack {
                HStack {
                    /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Content@*/Text("Content")/*@END_MENU_TOKEN@*/
                }
                Button(/*@START_MENU_TOKEN@*/"Button"/*@END_MENU_TOKEN@*/) {
                    /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Action@*/ /*@END_MENU_TOKEN@*/
                }
                .buttonStyle(.bordered)
            }
            TabView(selection: $selectedTab) {
                TimerView(25)
                .tag(1)
                TimerView(5)
                .tag(2)
                TimerView(15)
                .tag(3)
            }
            .tabViewStyle(.page)
            HStack {
                Button {
                    selectedTab = 1
                } label: {
                    Text("Pomodoro")
                    .padding(.bottom, 4)
                    .padding(.top, 4)
                }
                .buttonStyleFor(selected: selectedTab == 1)
                .contentShape(Rectangle())
                Button {
                    selectedTab = 2
                } label: {
                    Text("Short Break")
                    .padding(.bottom, 4)
                    .padding(.top, 4)
                }
                .buttonStyleFor(selected: selectedTab == 2)
                .contentShape(Rectangle())
                Button {
                    selectedTab = 3
                } label: {
                    Text("Long Break")
                    .padding(.bottom, 4)
                    .padding(.top, 4)
                }
                .buttonStyleFor(selected: selectedTab == 3)
                .contentShape(Rectangle())
            }
            .padding(.bottom, 0)
        }
    }
}

extension Button {
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
    }
}
