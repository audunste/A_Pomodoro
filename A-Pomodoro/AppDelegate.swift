//
//  AppDelegate.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 23/12/2022.
//

#if os(iOS)
import UIKit
import CoreData
import CloudKit

class AppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    func application(_ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    -> Bool
    {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        { success, error in
            if let error = error {
                ALog(level: .warning, error.localizedDescription)
            }
        }
        UNUserNotificationCenter.current().delegate = self
        #if !InitializeCloudKitSchema
        DispatchQueue.global(qos: .userInitiated).async {
            //PersistenceController.shared.startOver()
            PersistenceController.shared.makeSureDefaultsExist()
            //PersistenceController.shared.updatePomodoroShares()
            Thread.sleep(forTimeInterval: 5.0)
            PersistenceController.shared.printEntityCounts()
            Thread.sleep(forTimeInterval: 5.0)
            PersistenceController.shared.printEntityCounts()
        }
        #endif
        return true
    }

    func application(_ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions)
    -> UISceneConfiguration
    {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
           willPresent notification: UNNotification,
           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        ALog("notification in foreground")
        completionHandler(.sound)
    }

}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    /**
     To be able to accept a share, add a CKSharingSupported entry in the Info.plist file and set it to true.
     */
    func windowScene(_ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata)
    {
        let persistenceController = PersistenceController.shared
        let sharedStore = persistenceController.sharedPersistentStore
        let container = persistenceController.persistentCloudKitContainer
        container.acceptShareInvitations(from: [cloudKitShareMetadata], into: sharedStore) { (_, error) in
            if let error = error {
                ALog(level: .error, "Failed to accept share invitations: \(error)")
            }
        }
    }
}

#else // macOS

import AppKit
import CoreData
import CloudKit

class AppDelegate: NSResponder, NSApplicationDelegate, ObservableObject {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ALog("applicationDidFinishLaunching")
    }
}

#endif
