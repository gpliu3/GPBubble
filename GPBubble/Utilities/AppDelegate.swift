//
//  AppDelegate.swift
//  GPBubble
//

import UIKit
import UserNotifications
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification authorization on launch if needed
        Task { @MainActor in
            await NotificationManager.shared.checkAuthorizationStatus()
            if NotificationManager.shared.isAuthorized && NotificationManager.shared.notificationsEnabled {
                await NotificationManager.shared.scheduleAllNotifications()
            }
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge when app becomes active
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // User tapped the notification - could navigate to main view
        completionHandler()
    }
}
