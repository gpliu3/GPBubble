//
//  PendingTasksListView.swift
//  GPBubble
//

import SwiftUI
import SwiftData

struct PendingTasksListView: View {
    private static let futurePreviewHorizonDays = 90
    private static let futurePreviewLimit = 80

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted },
           sort: \TaskItem.createdAt)
    private var allTasks: [TaskItem]

    @State private var editingTask: TaskItem?

    private var sections: [(title: String, icon: String, items: [PendingListItem], tint: Color)] {
        var overdueItems: [PendingListItem] = []
        var todayItems: [PendingListItem] = []
        var upcomingItems: [PendingListItem] = []
        var somedayItems: [PendingListItem] = []

        for task in allTasks {
            let item = PendingListItem(task: task)
            if task.shouldShowInPastDue {
                overdueItems.append(item)
            } else if task.shouldShowToday {
                todayItems.append(item)
            } else if task.dueDate != nil {
                upcomingItems.append(item)
            } else {
                somedayItems.append(item)
            }
        }

        upcomingItems.append(contentsOf: projectedFutureItems(excluding: upcomingItems))

        overdueItems.sort { $0.task.sortScore > $1.task.sortScore }
        todayItems.sort { $0.task.sortScore > $1.task.sortScore }
        upcomingItems.sort { lhs, rhs in
            if let leftDueDate = lhs.displayDueDate, let rightDueDate = rhs.displayDueDate, leftDueDate != rightDueDate {
                return leftDueDate < rightDueDate
            }
            return lhs.task.sortScore > rhs.task.sortScore
        }
        somedayItems.sort { $0.task.sortScore > $1.task.sortScore }

        let categorizedSections: [(title: String, icon: String, items: [PendingListItem], tint: Color)] = [
            (L("pending.section.overdue"), "exclamationmark.triangle.fill", overdueItems, .red),
            (L("pending.section.today"), "sun.max.fill", todayItems, AppTheme.accent),
            (L("pending.section.upcoming"), "calendar", upcomingItems, AppTheme.primary),
            (L("pending.section.someday"), "tray.fill", somedayItems, AppTheme.secondary)
        ]

        return categorizedSections.filter { !$0.items.isEmpty }
    }

    var body: some View {
        let visibleSections = sections

        List {
            if visibleSections.isEmpty {
                emptyStateView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(visibleSections, id: \.title) { section in
                    Section {
                        ForEach(section.items) { item in
                            PendingTaskRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingTask = item.task
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !item.isProjected {
                                        Button {
                                            completeTask(item.task)
                                        } label: {
                                            Label(L("pending.complete"), systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(AppTheme.secondary)
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Image(systemName: section.icon)
                                .foregroundColor(section.tint)
                            Text(section.title)
                        }
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(L("pending.title"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 42))
                .foregroundColor(AppTheme.secondary)

            Text(L("pending.empty.title"))
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)

            Text(L("pending.empty.subtitle"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.surface)
        )
        .padding(.top, 32)
    }

    private func completeTask(_ task: TaskItem) {
        withAnimation {
            task.markComplete()

            if let nextTask = task.createNextRecurringTask() {
                modelContext.insert(nextTask)
            }
        }
    }

    private func projectedFutureItems(excluding existingItems: [PendingListItem]) -> [PendingListItem] {
        let calendar = Calendar.current
        let now = Date()
        guard let horizon = calendar.date(
            byAdding: .day,
            value: Self.futurePreviewHorizonDays,
            to: now
        ) else {
            return []
        }

        let existingKeys = Set(existingItems.compactMap { item -> String? in
            guard let dueDate = item.displayDueDate else { return nil }
            return projectionKey(taskID: item.task.id, date: dueDate, calendar: calendar)
        })

        var projected: [PendingListItem] = []
        for task in allTasks where task.isRecurring && !task.isCompleted {
            let anchor = task.dueDate ?? now
            var cursor = max(anchor, now)
            var guardCount = 0

            while projected.count < Self.futurePreviewLimit,
                  guardCount < Self.futurePreviewLimit,
                  let nextDate = nextRecurringDate(for: task, after: cursor, calendar: calendar),
                  nextDate <= horizon {
                guardCount += 1
                cursor = nextDate

                let key = projectionKey(taskID: task.id, date: nextDate, calendar: calendar)
                if existingKeys.contains(key) {
                    continue
                }

                projected.append(PendingListItem(task: task, projectedDueDate: nextDate))
            }
        }

        return projected
    }

    private func projectionKey(taskID: UUID, date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let parts = [
            taskID.uuidString,
            String(components.year ?? 0),
            String(components.month ?? 0),
            String(components.day ?? 0),
            String(components.hour ?? 0),
            String(components.minute ?? 0)
        ]
        return parts.joined(separator: "-")
    }

    private func nextRecurringDate(for task: TaskItem, after date: Date, calendar: Calendar) -> Date? {
        guard let interval = task.recurringInterval else { return nil }

        switch interval {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)

        case .weekly:
            if !task.weeklyDays.isEmpty {
                return nextWeeklyDate(after: date, weekdays: task.weeklyDays, calendar: calendar)
            }

            let step = max(1, 7 / max(task.recurringCount, 1))
            return calendar.date(byAdding: .day, value: step, to: date)

        case .monthly:
            switch task.monthlyPattern ?? .timesPerMonth {
            case .dayOfMonth:
                return nextDayOfMonth(after: date, day: task.monthlyDayOfMonth, calendar: calendar)
            case .nthWeekday:
                return nextNthWeekday(
                    after: date,
                    weekNumber: task.monthlyWeekNumber,
                    weekday: task.monthlyWeekday,
                    calendar: calendar
                )
            case .timesPerMonth:
                let step = max(1, 30 / max(task.recurringCount, 1))
                return calendar.date(byAdding: .day, value: step, to: date)
            }
        }
    }

    private func nextWeeklyDate(after date: Date, weekdays: [Int], calendar: Calendar) -> Date? {
        let selectedDays = Set(weekdays)
        for offset in 1...8 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if selectedDays.contains(calendar.component(.weekday, from: candidate)) {
                return candidate
            }
        }
        return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
    }

    private func nextDayOfMonth(after date: Date, day: Int, calendar: Calendar) -> Date? {
        for monthOffset in 0...13 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: date),
                  let range = calendar.range(of: .day, in: .month, for: monthDate) else {
                continue
            }

            var components = calendar.dateComponents([.year, .month, .hour, .minute], from: monthDate)
            components.day = day == 0 ? range.count : min(max(day, 1), range.count)

            if let candidate = calendar.date(from: components), candidate > date {
                return candidate
            }
        }

        return nil
    }

    private func nextNthWeekday(after date: Date, weekNumber: Int, weekday: Int, calendar: Calendar) -> Date? {
        for monthOffset in 0...13 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: date) else {
                continue
            }

            let monthComponents = calendar.dateComponents([.year, .month], from: monthDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
            var components = DateComponents()
            components.year = monthComponents.year
            components.month = monthComponents.month
            components.weekday = weekday

            if weekNumber == WeekNumber.last.rawValue {
                components.weekdayOrdinal = -1
            } else {
                components.weekdayOrdinal = min(max(weekNumber, 1), 4)
            }

            components.hour = timeComponents.hour
            components.minute = timeComponents.minute

            if let candidate = calendar.date(from: components), candidate > date {
                return candidate
            }
        }

        return nil
    }
}

private struct PendingListItem: Identifiable {
    let task: TaskItem
    let projectedDueDate: Date?

    init(task: TaskItem, projectedDueDate: Date? = nil) {
        self.task = task
        self.projectedDueDate = projectedDueDate
    }

    var id: String {
        if let projectedDueDate {
            return "\(task.id.uuidString)-projected-\(projectedDueDate.timeIntervalSince1970)"
        }
        return task.id.uuidString
    }

    var displayDueDate: Date? {
        projectedDueDate ?? task.dueDate
    }

    var isProjected: Bool {
        projectedDueDate != nil
    }
}

private struct PendingTaskRow: View {
    let item: PendingListItem

    private var task: TaskItem {
        item.task
    }

    private var priorityColor: Color {
        switch task.priority {
        case 1: return Color(red: 0.20, green: 0.68, blue: 0.52)
        case 2: return Color(red: 0.30, green: 0.74, blue: 0.63)
        case 3: return Color(red: 0.24, green: 0.57, blue: 0.86)
        case 4: return Color(red: 0.92, green: 0.54, blue: 0.28)
        case 5: return Color(red: 0.80, green: 0.31, blue: 0.30)
        default: return AppTheme.primary
        }
    }

    private var dueLabel: String? {
        guard let dueDate = item.displayDueDate else { return nil }

        if !item.isProjected && task.shouldShowInPastDue {
            return L("pending.section.overdue")
        }

        if Calendar.current.isDateInToday(dueDate) {
            return dueDate.formatted(.dateTime.hour().minute())
        }

        return dueDate.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(priorityColor)
                .frame(width: 6, height: 42)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(task.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text(task.priorityLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(priorityColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(priorityColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 6) {
                    taskMetaBadge(text: task.effortLabel, icon: "timer", tint: AppTheme.primary, compact: false)

                    if let dueLabel {
                        taskMetaBadge(text: dueLabel, icon: "calendar", tint: task.shouldShowInPastDue ? .red : AppTheme.accent, compact: false)
                    }

                    if task.isRecurring {
                        taskMetaBadge(text: nil, icon: "repeat", tint: AppTheme.secondary, compact: true)
                    }

                    if item.isProjected {
                        taskMetaBadge(text: nil, icon: "sparkles", tint: AppTheme.secondary, compact: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func taskMetaBadge(text: String?, icon: String, tint: Color, compact: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))

            if let text {
                Text(text)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .foregroundColor(tint)
        .padding(.horizontal, compact ? 7 : 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        PendingTasksListView()
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
