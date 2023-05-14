//
//  ContentSheetRouter.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 30/04/2023.
//

import Foundation
import SwiftUI


struct ContentSheetRouter: View {

    var sheet: SheetType

    var body: some View {
        switch sheet {
        case .history:
            #if os(macOS)
            HistoryView()
            .frame(width: 400, height: 600)
            #else
            HistoryView()
            #endif
        case .settings:
            #if os(macOS)
            SettingsView()
            .frame(width: 400, height: 600)
            #else
            SettingsView()
            #endif
        default:
            Text("No sheet")
        }
    }

}
