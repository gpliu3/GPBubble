//
//  NotificationManager.swift
//  GPBubble
//

import Foundation
import UserNotifications
import SwiftData
import Combine
import os.log

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            // Cancel all old notifications when settings change
            cancelAllNotifications()
        }
    }

    @Published var numberOfReminders: Int {
        didSet {
            UserDefaults.standard.set(numberOfReminders, forKey: "numberOfReminders")

            // Update reminderTimes array to match new count
            let calendar = Calendar.current
            while reminderTimes.count < numberOfReminders {
                // Add new reminder times (default to noon, 2pm, 4pm, etc.)
                let baseHour = 12 + (reminderTimes.count - 2) * 2
                var newTime = calendar.startOfDay(for: Date())
                newTime = calendar.date(byAdding: .hour, value: baseHour, to: newTime) ?? newTime
                reminderTimes.append(newTime)
            }
            while reminderTimes.count > numberOfReminders {
                // Remove excess reminder times
                reminderTimes.removeLast()
            }

            // Cancel all old notifications when settings change
            if notificationsEnabled {
                cancelAllNotifications()
            }
        }
    }

    @Published var reminderTimes: [Date] {
        didSet {
            // Store as time intervals from midnight
            let timeIntervals = reminderTimes.map { getTimeIntervalFromMidnight($0) }
            UserDefaults.standard.set(timeIntervals, forKey: "reminderTimes")
            // Cancel all old notifications when settings change
            if notificationsEnabled {
                cancelAllNotifications()
            }
        }
    }

    private init() {
        // Load saved settings
        let savedEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        let savedReminders = UserDefaults.standard.integer(forKey: "numberOfReminders")

        self.notificationsEnabled = savedEnabled
        self.numberOfReminders = savedReminders == 0 ? 2 : savedReminders

        // Load reminder times or use defaults (8am and 6pm)
        if let savedTimeIntervals = UserDefaults.standard.array(forKey: "reminderTimes") as? [TimeInterval] {
            self.reminderTimes = savedTimeIntervals.map { interval in
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                return today.addingTimeInterval(interval)
            }
        } else {
            // Default times: 8am and 6pm
            let calendar = Calendar.current
            var morning = calendar.startOfDay(for: Date())
            var evening = calendar.startOfDay(for: Date())
            morning = calendar.date(byAdding: .hour, value: 8, to: morning) ?? morning
            evening = calendar.date(byAdding: .hour, value: 18, to: evening) ?? evening
            self.reminderTimes = [morning, evening]
        }
    }

    /// Request notification permission
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted && notificationsEnabled {
                await scheduleAllNotifications()
            }
        } catch {
            os_log(.error, "Failed to request notification authorization: %@", error.localizedDescription)
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    /// Schedule all daily reminder notifications - placeholder for compatibility
    func scheduleAllNotifications() async {
        // Notifications are now scheduled dynamically with actual task content
        // This method exists for compatibility but does nothing
        // Real scheduling happens in scheduleNotificationWithTasks
    }

    /// Cancel all scheduled notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Schedule a one-time notification for next reminder with task content
    func scheduleNotificationWithTasks(_ tasks: [TaskItem]) async {
        guard isAuthorized && notificationsEnabled else { return }

        let now = Date()
        let calendar = Calendar.current

        // Find the next reminder time
        let timesToUse = Array(reminderTimes.prefix(numberOfReminders))
        var nextReminderDate: Date?

        for time in timesToUse {
            // Create today's date with this time
            let components = calendar.dateComponents([.hour, .minute], from: time)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
            dateComponents.hour = components.hour
            dateComponents.minute = components.minute

            if let reminderDate = calendar.date(from: dateComponents) {
                if reminderDate > now {
                    nextReminderDate = reminderDate
                    break
                }
            }
        }

        // If no reminder today, schedule for tomorrow's first reminder
        if nextReminderDate == nil, let firstTime = timesToUse.first {
            let components = calendar.dateComponents([.hour, .minute], from: firstTime)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: 1, to: now)!)
            dateComponents.hour = components.hour
            dateComponents.minute = components.minute
            nextReminderDate = calendar.date(from: dateComponents)
        }

        guard let nextDate = nextReminderDate else { return }

        // Create notification content with task list
        let content = UNMutableNotificationContent()
        content.title = L("notification.reminder.title")

        if tasks.isEmpty {
            content.body = L("notification.no.tasks")
        } else {
            // Simply list task titles separated by comma and space
            content.body = tasks.map { $0.title }.joined(separator: ", ")
        }

        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.interruptionLevel = .timeSensitive
        content.badge = tasks.count as NSNumber

        // Schedule for next reminder time
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "next-task-reminder",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helper Methods

    /// Create a date with specific hour and minute
    private func createDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    /// Get time interval from midnight
    private func getTimeIntervalFromMidnight(_ date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: date)
        return date.timeIntervalSince(midnight)
    }

    /// Create date from time interval since midnight
    private func createDateFromTimeInterval(_ interval: TimeInterval) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return today.addingTimeInterval(interval)
    }
}
