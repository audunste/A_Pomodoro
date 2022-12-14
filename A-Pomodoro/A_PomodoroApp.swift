//
//  A_PomodoroApp.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 21/12/2022.
//

import SwiftUI

@main
struct A_PomodoroApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    #else
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    #endif
    let persistentContainer = PersistenceController.shared.persistentContainer
    @StateObject private var modelData = ModelData()
    @StateObject private var lastPomodoroEntryBinder = LatestObjectBinder<PomodoroEntry>(
        container: PersistenceController.shared.persistentContainer,
        sortKey: "startDate")

    init() {
    }

    var body: some Scene {
        #if InitializeCloudKitSchema
        WindowGroup {
            Text("Initializing CloudKit Schema...").font(.title)
            Text("Stop after Xcode says 'no more requests to execute', " +
                 "then check with CloudKit Console if the schema is created correctly.").padding()
        }
        #else
        WindowGroup {
            GeometryReader() { geometry in
                ContentView()
                    .environment(\.managedObjectContext, persistentContainer.viewContext)
                    .environment(\.mainWindowSize, geometry.size)
                    .environmentObject(modelData)
                    .environmentObject(lastPomodoroEntryBinder)
                    .preferredColorScheme(.dark)
            }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
        #endif
    }
}
