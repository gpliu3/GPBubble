//
//  TaskItem.swift
//  BubbleTodo
//

import Foundation
import SwiftData

enum RecurringInterval: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var displayName: String {
        switch self {
        case .daily: return L("recurring.daily")
        case .weekly: return L("recurring.weekly")
        case .monthly: return L("recurring.monthly")
        }
    }
}

enum MonthlyPattern: String, Codable, CaseIterable {
    case timesPerMonth = "TimesPerMonth"  // X times per month (no specific day)
    case dayOfMonth = "DayOfMonth"        // Specific day (e.g., 5th, 15th, last day)
    case nthWeekday = "NthWeekday"        // Nth weekday (e.g., 3rd Wednesday)

    var displayName: String {
        switch self {
        case .timesPerMonth: return L("monthly.pattern.times")
        case .dayOfMonth: return L("monthly.pattern.day")
        case .nthWeekday: return L("monthly.pattern.weekday")
        }
    }
}

enum WeekNumber: Int, Codable, CaseIterable, Identifiable {
    case first = 1
    case second = 2
    case third = 3
    case fourth = 4
    case last = 5

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .first: return L("weeknumber.first")
        case .second: return L("weeknumber.second")
        case .third: return L("weeknumber.third")
        case .fourth: return L("weeknumber.fourth")
        case .last: return L("weeknumber.last")
        }
    }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return L("weekday.sun.short")
        case .monday: return L("weekday.mon.short")
        case .tuesday: return L("weekday.tue.short")
        case .wednesday: return L("weekday.wed.short")
        case .thursday: return L("weekday.thu.short")
        case .friday: return L("weekday.fri.short")
        case .saturday: return L("weekday.sat.short")
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return L("weekday.sunday")
        case .monday: return L("weekday.monday")
        case .tuesday: return L("weekday.tuesday")
        case .wednesday: return L("weekday.wednesday")
        case .thursday: return L("weekday.thursday")
        case .friday: return L("weekday.friday")
        case .saturday: return L("weekday.saturday")
        }
    }
}

enum DueDateType: String, Codable, CaseIterable {
    case on = "On"       // Task only for that specific day
    case before = "Before"  // Deadline - must be done before/at date

    var displayName: String {
        switch self {
        case .on: return L("duedate.on")
        case .before: return L("duedate.before")
        }
    }

    var description: String {
        switch self {
        case .on: return L("duedate.on.footer")
        case .before: return L("duedate.before.footer")
        }
    }
}

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var priority: Int = 3 // 1-5, where 5 is highest
    var weight: Double = 1.0 // starts at 1.0, increases over time
    var effort: Double = 1.0 // user-input effort/weight for tracking total work done
    var dueDate: Date?
    var dueDateType: DueDateType? = nil // "On" vs "Before"
    var isRecurring: Bool = false
    var recurringInterval: RecurringInterval?
    var recurringCount: Int = 1 // how many times per period (e.g., 3 times per week)
    var weeklyDays: [Int] = [] // specific days for weekly recurrence (1=Sun, 2=Mon, etc.)
    var monthlyPattern: MonthlyPattern? // pattern type for monthly recurrence
    var monthlyDayOfMonth: Int = 1 // day of month (1-31, or 0 for "last day")
    var monthlyWeekNumber: Int = 1 // which week (1-4, or 5 for "last")
    var monthlyWeekday: Int = 2 // weekday for nth pattern (1=Sun, 2=Mon, etc.)
    var createdAt: Date = Date()
    var completedAt: Date?
    var isCompleted: Bool = false

    // Shared calendar for performance (avoid creating new Calendar instances)
    private static let sharedCalendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    init(
        id: UUID = UUID(),
        title: String,
        priority: Int = 3,
        weight: Double = 1.0,
        effort: Double = 1.0,
        dueDate: Date? = nil,
        dueDateType: DueDateType = .before,
        isRecurring: Bool = false,
        recurringInterval: RecurringInterval? = nil,
        recurringCount: Int = 1,
        weeklyDays: [Int] = [],
        monthlyPattern: MonthlyPattern? = nil,
        monthlyDayOfMonth: Int = 1,
        monthlyWeekNumber: Int = 1,
        monthlyWeekday: Int = 2,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.priority = min(max(priority, 1), 5) // Clamp between 1-5
        self.weight = weight
        self.effort = effort
        self.dueDate = dueDate
        self.dueDateType = dueDateType
        self.isRecurring = isRecurring
        self.recurringInterval = recurringInterval
        self.recurringCount = recurringCount
        self.weeklyDays = weeklyDays
        self.monthlyPattern = monthlyPattern
        self.monthlyDayOfMonth = monthlyDayOfMonth
        self.monthlyWeekNumber = monthlyWeekNumber
        self.monthlyWeekday = monthlyWeekday
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.isCompleted = isCompleted
    }

    // MARK: - Computed Properties

    /// Effective due date type with default fallback
    var effectiveDueDateType: DueDateType {
        dueDateType ?? .before
    }

    /// Calculates the effective urgency weight (increases over time)
    var effectiveWeight: Double {
        var currentWeight = weight
        let now = Date()

        if let dueDate = dueDate {
            if now > dueDate {
                // Past due date - increase weight significantly
                let hoursOverdue = now.timeIntervalSince(dueDate) / 3600
                currentWeight += hoursOverdue * 0.1
            } else if effectiveDueDateType == .before {
                // "Before" type: Gradually increase urgency as approaching deadline
                let hoursUntilDue = dueDate.timeIntervalSince(now) / 3600

                if hoursUntilDue < 24 {
                    // Within 24 hours: urgency increases dramatically
                    let urgencyMultiplier = 1.0 + (24 - hoursUntilDue) / 24 * 0.5
                    currentWeight *= urgencyMultiplier
                } else if hoursUntilDue < 72 {
                    // Within 3 days: moderate urgency increase
                    let urgencyMultiplier = 1.0 + (72 - hoursUntilDue) / 72 * 0.3
                    currentWeight *= urgencyMultiplier
                }
            }
            // For "on" type: no early urgency increase
        } else {
            // No due date - slight increase for old tasks
            let hoursSinceCreation = now.timeIntervalSince(createdAt) / 3600
            if hoursSinceCreation > 24 {
                let hoursAfter24 = hoursSinceCreation - 24
                currentWeight += hoursAfter24 * 0.05
            }
        }

        return currentWeight
    }

    /// Bubble size is based on EFFORT with sqrt scaling
    /// This ensures 120min tasks aren't 120x bigger than 1min tasks
    /// Scale: 1min → ~1, 5min → ~2.2, 15min → ~3.9, 30min → ~5.5, 60min → ~7.7, 120min → ~11
    var bubbleSize: Double {
        sqrt(effort)
    }

    /// Effort displayed as time label
    var effortLabel: String {
        switch Int(effort) {
        case 0...1: return "1m"
        case 2...5: return "5m"
        case 6...15: return "15m"
        case 16...30: return "30m"
        case 31...60: return "1h"
        case 61...120: return "2h"
        default: return "\(Int(effort))m"
        }
    }

    /// Standard effort options in minutes (computed for localization support)
    static var effortOptions: [(value: Double, label: String)] {
        effortValues.map { ($0.value, L($0.key)) }
    }

    /// Static effort values (non-localized keys)
    private static let effortValues: [(value: Double, key: String)] = [
        (1, "effort.1min"),
        (5, "effort.5min"),
        (15, "effort.15min"),
        (30, "effort.30min"),
        (60, "effort.1hour"),
        (120, "effort.2hours")
    ]

    /// Sort score for ordering (higher = more urgent, appears at top)
    /// Based on: 1) Priority, 2) Due time today, 3) Time-based urgency
    var sortScore: Double {
        let now = Date()
        let calendar = Self.sharedCalendar

        // Base score from priority (1-5) - scale to 2000-10000
        // Using 2000 per level ensures priority dominates over urgency bonuses
        var score = Double(priority) * 2000.0

        // Add urgency from due date/time
        if let dueDate = dueDate {
            // Check if due today
            if calendar.isDateInToday(dueDate) {
                // Due today: add score based on time of day (earlier = higher)
                let hoursUntilDue = dueDate.timeIntervalSince(now) / 3600

                if hoursUntilDue > 0 {
                    // Due later today: 0-24 hours away, add 0-500 points (sooner = more points)
                    score += max(0, 500 - (hoursUntilDue * 20))
                } else {
                    // Overdue today: add even more urgency
                    let hoursOverdue = abs(hoursUntilDue)
                    score += 500 + (hoursOverdue * 100)
                }
            } else if dueDate < now {
                // Overdue from previous days: very high urgency
                let hoursOverdue = now.timeIntervalSince(dueDate) / 3600
                score += 1000 + (hoursOverdue * 50)
            } else if effectiveDueDateType == .before {
                // "Before" type with future due date: add urgency as deadline approaches
                let hoursUntilDue = dueDate.timeIntervalSince(now) / 3600

                if hoursUntilDue < 24 {
                    // Within 24 hours: 200-400 points
                    score += 200 + (24 - hoursUntilDue) * 8
                } else if hoursUntilDue < 72 {
                    // Within 3 days: 0-200 points
                    score += (72 - hoursUntilDue) * 2.8
                }
            }
        } else {
            // No due date: slight boost for older tasks
            let hoursSinceCreation = now.timeIntervalSince(createdAt) / 3600
            if hoursSinceCreation > 24 {
                score += min((hoursSinceCreation - 24) * 2, 100)
            }
        }

        return score
    }

    /// Whether this task should be visible today
    /// Behavior depends on dueDateType
    var shouldShowToday: Bool {
        guard !isCompleted else { return false }

        // No due date = always show
        guard let dueDate = dueDate else { return true }

        let calendar = Self.sharedCalendar
        let now = Date()

        // Recurring tasks always use .on behavior (only show on scheduled day)
        let typeToUse = isRecurring ? DueDateType.on : effectiveDueDateType

        switch typeToUse {
        case .on:
            // "On" type: Only show on the specific day
            let startOfDueDate = calendar.startOfDay(for: dueDate)
            let endOfDueDate = calendar.date(byAdding: .day, value: 1, to: startOfDueDate)!

            // Show if today is the due date OR if overdue
            if now >= startOfDueDate && now < endOfDueDate {
                return true // Today is the due date
            } else if now >= endOfDueDate {
                return true // Overdue
            } else {
                return false // Before the due date - don't show
            }

        case .before:
            // "Before" type: Show from creation until end of deadline day
            // This ensures task shows all day on the due date, not just until the exact time
            let endOfDueDateDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dueDate))!
            return now < endOfDueDateDay
        }
    }

    /// Whether this task should be visible on a specific date
    /// Used for browsing future dates
    func shouldShowOnDate(_ targetDate: Date) -> Bool {
        guard !isCompleted else { return false }

        let calendar = Self.sharedCalendar
        let startOfTargetDate = calendar.startOfDay(for: targetDate)
        let endOfTargetDate = calendar.date(byAdding: .day, value: 1, to: startOfTargetDate)!
        let now = Date()
        let isTargetToday = calendar.isDateInToday(targetDate)
        let isTargetInFuture = startOfTargetDate > calendar.startOfDay(for: now)

        // No due date = only show on today (not future dates)
        guard let taskDueDate = dueDate else {
            return isTargetToday
        }

        let startOfDueDate = calendar.startOfDay(for: taskDueDate)

        // Handle recurring tasks specially - check if pattern matches target date
        if isRecurring, let interval = recurringInterval {
            // For recurring tasks, check if the pattern would occur on target date
            return wouldRecurOnDate(targetDate, interval: interval, calendar: calendar)
        }

        // Non-recurring tasks use original logic
        let typeToUse = effectiveDueDateType

        switch typeToUse {
        case .on:
            // "On" type: Show only on the specific day, or if overdue and viewing today/past
            if startOfDueDate == startOfTargetDate {
                return true // Target date matches due date
            } else if startOfDueDate < startOfTargetDate && isTargetToday {
                return true // Overdue and viewing today
            }
            return false

        case .before:
            // "Before" type: Show from creation until due date
            if isTargetInFuture {
                // For future dates, only show if due date is on or after target
                return startOfDueDate >= startOfTargetDate
            } else {
                // For today or past, show if not yet past due date
                return startOfTargetDate < endOfTargetDate && startOfDueDate >= startOfTargetDate
            }
        }
    }

    /// Check if a recurring task would occur on a specific date based on its pattern
    private func wouldRecurOnDate(_ targetDate: Date, interval: RecurringInterval, calendar: Calendar) -> Bool {
        guard let taskDueDate = dueDate else { return false }

        let startOfTargetDate = calendar.startOfDay(for: targetDate)
        let startOfDueDate = calendar.startOfDay(for: taskDueDate)

        // If target is before the task's due date, don't show
        // (the task hasn't "started" yet)
        if startOfTargetDate < startOfDueDate {
            return false
        }

        // If target matches current due date exactly, show it
        if startOfTargetDate == startOfDueDate {
            return true
        }

        switch interval {
        case .daily:
            // Daily tasks occur every day from their start date
            return true

        case .weekly:
            let targetWeekday = calendar.component(.weekday, from: targetDate)

            if !weeklyDays.isEmpty {
                // Specific days selected (e.g., Mon, Wed, Fri)
                return weeklyDays.contains(targetWeekday)
            } else if recurringCount > 1 {
                // X times per week - check if target is a valid slot
                // Simplified: show on evenly spaced days
                let dayInterval = 7 / recurringCount
                let daysSinceStart = calendar.dateComponents([.day], from: startOfDueDate, to: startOfTargetDate).day ?? 0
                let dayOfWeek = daysSinceStart % 7
                // Check if this day falls on one of the slots
                for slot in 0..<recurringCount {
                    if dayOfWeek == (slot * dayInterval) % 7 {
                        return true
                    }
                }
                return false
            } else {
                // Once per week - same weekday as original
                let originalWeekday = calendar.component(.weekday, from: taskDueDate)
                return targetWeekday == originalWeekday
            }

        case .monthly:
            let pattern = monthlyPattern ?? .timesPerMonth
            let targetDay = calendar.component(.day, from: targetDate)
            let targetMonth = calendar.component(.month, from: targetDate)
            let targetYear = calendar.component(.year, from: targetDate)

            switch pattern {
            case .dayOfMonth:
                if monthlyDayOfMonth == 0 {
                    // Last day of month
                    if let lastDay = lastDayOfMonth(year: targetYear, month: targetMonth, calendar: calendar) {
                        return targetDay == lastDay
                    }
                    return false
                } else {
                    // Specific day of month
                    let daysInMonth = lastDayOfMonth(year: targetYear, month: targetMonth, calendar: calendar) ?? 28
                    let effectiveDay = min(monthlyDayOfMonth, daysInMonth)
                    return targetDay == effectiveDay
                }

            case .nthWeekday:
                // Check if target is the nth weekday of its month
                let targetWeekday = calendar.component(.weekday, from: targetDate)
                if targetWeekday != monthlyWeekday {
                    return false
                }
                // Check which occurrence this is
                let weekOfMonth = (targetDay - 1) / 7 + 1
                if monthlyWeekNumber == 5 {
                    // "Last" - check if this is the last occurrence
                    if let nthDate = lastWeekdayOfMonth(year: targetYear, month: targetMonth, weekday: monthlyWeekday, calendar: calendar) {
                        return calendar.isDate(targetDate, inSameDayAs: nthDate)
                    }
                    return false
                } else {
                    return weekOfMonth == monthlyWeekNumber
                }

            case .timesPerMonth:
                if recurringCount <= 1 {
                    // Once per month - same day of month as original
                    let originalDay = calendar.component(.day, from: taskDueDate)
                    let daysInMonth = lastDayOfMonth(year: targetYear, month: targetMonth, calendar: calendar) ?? 28
                    let effectiveDay = min(originalDay, daysInMonth)
                    return targetDay == effectiveDay
                } else {
                    // X times per month - evenly spaced
                    let dayInterval = 30 / recurringCount
                    for slot in 0..<recurringCount {
                        let slotDay = 1 + (slot * dayInterval)
                        if targetDay == slotDay {
                            return true
                        }
                    }
                    return false
                }
            }
        }
    }

    /// Check if task is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return Date() > dueDate
    }

    /// Check if task is due today
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Self.sharedCalendar.isDateInToday(dueDate)
    }

    /// Priority label for display
    var priorityLabel: String {
        switch priority {
        case 1: return L("priority.low")
        case 2: return L("priority.medium")
        case 3: return L("priority.high")
        case 4: return L("priority.urgent")
        case 5: return L("priority.critical")
        default: return L("priority.medium")
        }
    }

    /// Color based on priority (green→yellow→orange→red→purple for 1-5)
    var priorityColorName: String {
        switch priority {
        case 1: return "green"
        case 2: return "yellow"
        case 3: return "orange"
        case 4: return "red"
        case 5: return "purple"
        default: return "orange"
        }
    }

    // MARK: - Methods

    /// Marks the task as complete
    func markComplete() {
        isCompleted = true
        completedAt = Date()
    }

    /// Undoes the completion
    func undoComplete() {
        isCompleted = false
        completedAt = nil
    }

    /// Creates the next recurring task if this is a recurring task
    func createNextRecurringTask() -> TaskItem? {
        guard isRecurring, let interval = recurringInterval else { return nil }

        let calendar = Self.sharedCalendar // Already configured with Monday as first weekday
        let now = Date()
        var nextDueDate: Date

        switch interval {
        case .daily:
            // Next occurrence is tomorrow
            nextDueDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        case .weekly:
            if !weeklyDays.isEmpty {
                // Find next occurrence based on selected weekdays (Mon/Wed/Fri)
                nextDueDate = findNextWeeklyDate(from: now, weekdays: weeklyDays, calendar: calendar) ?? now
            } else if recurringCount > 1 {
                // X times per week - find next slot starting from Monday
                nextDueDate = findNextWeeklySlot(from: now, count: recurringCount, calendar: calendar) ?? now
            } else {
                // Once per week - next Monday
                nextDueDate = findNextMonday(from: now, calendar: calendar) ?? now
            }

        case .monthly:
            let pattern = monthlyPattern ?? .timesPerMonth
            switch pattern {
            case .dayOfMonth:
                // Specific day of month (e.g., 5th, 15th, or last day)
                nextDueDate = findNextDayOfMonth(from: now, day: monthlyDayOfMonth, calendar: calendar) ?? now

            case .nthWeekday:
                // Nth weekday of month (e.g., 3rd Wednesday)
                nextDueDate = findNextNthWeekday(from: now, weekNumber: monthlyWeekNumber, weekday: monthlyWeekday, calendar: calendar) ?? now

            case .timesPerMonth:
                if recurringCount > 1 {
                    // X times per month - space evenly from 1st of month
                    nextDueDate = findNextMonthlySlot(from: now, count: recurringCount, calendar: calendar) ?? now
                } else {
                    // Once per month - 1st of next month
                    nextDueDate = findFirstOfNextMonth(from: now, calendar: calendar) ?? now
                }
            }
        }

        return TaskItem(
            title: title,
            priority: priority,
            weight: 1.0,
            effort: effort,
            dueDate: nextDueDate,
            dueDateType: effectiveDueDateType,
            isRecurring: true,
            recurringInterval: interval,
            recurringCount: recurringCount,
            weeklyDays: weeklyDays,
            monthlyPattern: monthlyPattern,
            monthlyDayOfMonth: monthlyDayOfMonth,
            monthlyWeekNumber: monthlyWeekNumber,
            monthlyWeekday: monthlyWeekday
        )
    }

    /// Finds the next date that matches one of the selected weekdays (starting tomorrow)
    private func findNextWeeklyDate(from date: Date, weekdays: [Int], calendar: Calendar) -> Date? {
        var checkDate = date

        // Convert iOS weekday (1=Sun, 2=Mon) to our weekday (1=Sun, 2=Mon)
        // weekdays array uses iOS convention where 1=Sun, 2=Mon, etc.

        for _ in 1...8 {
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
            let weekday = calendar.component(.weekday, from: checkDate)

            if weekdays.contains(weekday) {
                return checkDate
            }
        }

        return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
    }

    /// Find next Monday (week start)
    private func findNextMonday(from date: Date, calendar: Calendar) -> Date? {
        var checkDate = date

        for _ in 1...8 {
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
            let weekday = calendar.component(.weekday, from: checkDate)

            if weekday == 2 { // Monday (in iOS calendar: 1=Sun, 2=Mon)
                return checkDate
            }
        }

        return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
    }

    /// Find next slot for X times per week (space evenly Mon-Sun)
    private func findNextWeeklySlot(from date: Date, count: Int, calendar: Calendar) -> Date? {
        let dayInterval = 7 / count // e.g., 3x/week = every 2-3 days

        // Simple approach: add dayInterval days from today
        var nextDate = calendar.date(byAdding: .day, value: dayInterval, to: date) ?? date

        // If we've gone past Sunday, wrap to next Monday
        let nextWeekday = calendar.component(.weekday, from: nextDate)
        if nextWeekday == 1 { // Sunday, wrap to Monday
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }

        return nextDate
    }

    /// Find 1st of next month
    private func findFirstOfNextMonth(from date: Date, calendar: Calendar) -> Date? {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        let components = calendar.dateComponents([.year, .month], from: nextMonth)
        return calendar.date(from: components)
    }

    /// Find next slot for X times per month (starting from 1st)
    private func findNextMonthlySlot(from date: Date, count: Int, calendar: Calendar) -> Date? {
        let dayInterval = 30 / count // e.g., 3x/month = every ~10 days

        var nextDate = calendar.date(byAdding: .day, value: dayInterval, to: date) ?? date

        // Check if we've crossed into next month
        let nextMonth = calendar.component(.month, from: nextDate)
        let currentMonth = calendar.component(.month, from: date)

        if nextMonth != currentMonth {
            // Wrap to 1st of next month
            let components = calendar.dateComponents([.year, .month], from: nextDate)
            nextDate = calendar.date(from: components) ?? nextDate
        }

        return nextDate
    }

    /// Find next occurrence of a specific day of month (e.g., 5th, 15th)
    /// Pass day=0 for "last day of month"
    private func findNextDayOfMonth(from date: Date, day: Int, calendar: Calendar) -> Date? {
        let currentDay = calendar.component(.day, from: date)
        let currentMonth = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: date)

        // Handle "last day of month" (day == 0)
        if day == 0 {
            // Find last day of current month
            if let lastDayThisMonth = lastDayOfMonth(year: currentYear, month: currentMonth, calendar: calendar),
               lastDayThisMonth > currentDay {
                // Last day is still ahead this month
                var components = calendar.dateComponents([.year, .month], from: date)
                components.day = lastDayThisMonth
                return calendar.date(from: components)
            } else {
                // Move to last day of next month
                let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: date) ?? date
                let nextMonth = calendar.component(.month, from: nextMonthDate)
                let nextYear = calendar.component(.year, from: nextMonthDate)
                if let lastDayNextMonth = lastDayOfMonth(year: nextYear, month: nextMonth, calendar: calendar) {
                    var components = DateComponents()
                    components.year = nextYear
                    components.month = nextMonth
                    components.day = lastDayNextMonth
                    return calendar.date(from: components)
                }
            }
            return nil
        }

        // Regular day of month (1-31)
        let targetDay = min(day, 28) // Clamp to 28 for safety, handle edge cases below

        if targetDay > currentDay {
            // Target day is still ahead this month
            let daysInMonth = lastDayOfMonth(year: currentYear, month: currentMonth, calendar: calendar) ?? 28
            var components = calendar.dateComponents([.year, .month], from: date)
            components.day = min(day, daysInMonth)
            return calendar.date(from: components)
        } else {
            // Target day has passed, move to next month
            let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: date) ?? date
            let nextMonth = calendar.component(.month, from: nextMonthDate)
            let nextYear = calendar.component(.year, from: nextMonthDate)
            let daysInNextMonth = lastDayOfMonth(year: nextYear, month: nextMonth, calendar: calendar) ?? 28

            var components = DateComponents()
            components.year = nextYear
            components.month = nextMonth
            components.day = min(day, daysInNextMonth)
            return calendar.date(from: components)
        }
    }

    /// Find next occurrence of nth weekday of month (e.g., 3rd Wednesday)
    /// weekNumber: 1-4 for specific week, 5 for "last"
    /// weekday: 1=Sunday, 2=Monday, etc.
    private func findNextNthWeekday(from date: Date, weekNumber: Int, weekday: Int, calendar: Calendar) -> Date? {
        let currentMonth = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: date)

        // Try this month first
        if let thisMonthDate = nthWeekdayOfMonth(year: currentYear, month: currentMonth, weekNumber: weekNumber, weekday: weekday, calendar: calendar),
           thisMonthDate > date {
            return thisMonthDate
        }

        // Move to next month
        let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        let nextMonth = calendar.component(.month, from: nextMonthDate)
        let nextYear = calendar.component(.year, from: nextMonthDate)

        return nthWeekdayOfMonth(year: nextYear, month: nextMonth, weekNumber: weekNumber, weekday: weekday, calendar: calendar)
    }

    /// Helper: Get the last day of a given month
    private func lastDayOfMonth(year: Int, month: Int, calendar: Calendar) -> Int? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return nil
        }
        return range.count
    }

    /// Helper: Get the nth weekday of a given month
    /// weekNumber: 1-4 for specific week, 5 for "last"
    private func nthWeekdayOfMonth(year: Int, month: Int, weekNumber: Int, weekday: Int, calendar: Calendar) -> Date? {
        if weekNumber == 5 {
            // "Last" weekday of the month
            return lastWeekdayOfMonth(year: year, month: month, weekday: weekday, calendar: calendar)
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = weekNumber // 1st, 2nd, 3rd, 4th

        return calendar.date(from: components)
    }

    /// Helper: Get the last occurrence of a weekday in a given month
    private func lastWeekdayOfMonth(year: Int, month: Int, weekday: Int, calendar: Calendar) -> Date? {
        // Start from last day of month and work backwards
        guard let daysInMonth = lastDayOfMonth(year: year, month: month, calendar: calendar) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = daysInMonth

        guard let lastDay = calendar.date(from: components) else { return nil }

        // Find the last occurrence of the weekday
        for offset in 0..<7 {
            guard let checkDate = calendar.date(byAdding: .day, value: -offset, to: lastDay) else { continue }
            let checkWeekday = calendar.component(.weekday, from: checkDate)
            if checkWeekday == weekday {
                return checkDate
            }
        }

        return nil
    }

    /// Summary of recurring schedule for display
    var recurringDescription: String? {
        guard isRecurring, let interval = recurringInterval else { return nil }

        switch interval {
        case .daily:
            return "Every day"
        case .weekly:
            if !weeklyDays.isEmpty {
                let dayNames = weeklyDays.sorted().compactMap { Weekday(rawValue: $0)?.shortName }
                return dayNames.joined(separator: ", ")
            } else if recurringCount > 1 {
                return "\(recurringCount)x per week"
            }
            return "Every week"
        case .monthly:
            let pattern = monthlyPattern ?? .timesPerMonth
            switch pattern {
            case .dayOfMonth:
                if monthlyDayOfMonth == 0 {
                    return L("monthly.lastday")
                } else {
                    return String(format: L("monthly.day.format"), ordinalSuffix(for: monthlyDayOfMonth))
                }
            case .nthWeekday:
                let weekNumberName = WeekNumber(rawValue: monthlyWeekNumber)?.displayName ?? ""
                let weekdayName = Weekday(rawValue: monthlyWeekday)?.fullName ?? ""
                return "\(weekNumberName) \(weekdayName)"
            case .timesPerMonth:
                if recurringCount > 1 {
                    return "\(recurringCount)x per month"
                }
                return "Every month"
            }
        }
    }

    /// Helper: Get ordinal suffix for a number (1st, 2nd, 3rd, etc.)
    private func ordinalSuffix(for number: Int) -> String {
        let suffix: String
        let ones = number % 10
        let tens = (number / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(number)\(suffix)"
    }
}
