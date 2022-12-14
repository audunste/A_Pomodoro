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
                print(error.localizedDescription)
            }
        }
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
        if let container = persistenceController.persistentContainer as? NSPersistentCloudKitContainer {
            container.acceptShareInvitations(from: [cloudKitShareMetadata], into: sharedStore) { (_, error) in
                if let error = error {
                    print("\(#function): Failed to accept share invitations: \(error)")
                }
            }
        }
    }
}
#else

import AppKit
import CoreData
import CloudKit

class AppDelegate: NSResponder, NSApplicationDelegate, ObservableObject {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("apom applicationDidFinishLaunching")
    }
}

#endif
