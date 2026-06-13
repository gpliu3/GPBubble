//
//  PendingTasksListView.swift
//  GPBubble
//

import SwiftUI
import SwiftData

struct PendingTasksListView: View {
    private static let futurePreviewHorizonDays = 120
    private static let futurePreviewLimit = 240
    private static let maxProjectedItemsPerTask = 30

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted },
           sort: \TaskItem.createdAt)
    private var allTasks: [TaskItem]

    @State private var editingTask: TaskItem?

    private var sections: [PendingDateSection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var datedItems: [Date: [PendingListItem]] = [:]
        var somedayItems: [PendingListItem] = []

        for task in allTasks {
            let item = PendingListItem(task: task)
            guard let displayDate = item.displayDueDate else {
                somedayItems.append(item)
                continue
            }

            datedItems[calendar.startOfDay(for: displayDate), default: []].append(item)
        }

        for item in projectedFutureItems(excluding: datedItems.values.flatMap { $0 }) {
            guard let displayDate = item.displayDueDate else { continue }
            datedItems[calendar.startOfDay(for: displayDate), default: []].append(item)
        }

        var result = datedItems.keys.sorted { sortSectionDates($0, $1, today: today) }.compactMap { date -> PendingDateSection? in
            guard var items = datedItems[date], !items.isEmpty else { return nil }
            items.sort(by: sortItemsWithinDate)
            return PendingDateSection(
                date: date,
                title: sectionTitle(for: date, calendar: calendar),
                subtitle: sectionSubtitle(for: date, calendar: calendar),
                icon: sectionIcon(for: date, calendar: calendar),
                tint: sectionTint(for: date, calendar: calendar),
                items: items
            )
        }

        if !somedayItems.isEmpty {
            somedayItems.sort { $0.task.sortScore > $1.task.sortScore }
            result.append(
                PendingDateSection(
                    date: nil,
                    title: L("pending.section.someday"),
                    subtitle: nil,
                    icon: "tray.fill",
                    tint: AppTheme.secondary,
                    items: somedayItems
                )
            )
        }

        return result
    }

    var body: some View {
        let visibleSections = sections

        List {
            if visibleSections.isEmpty {
                emptyStateView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(visibleSections) { section in
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
                        PendingSectionHeader(section: section)
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

    private func sortItemsWithinDate(_ lhs: PendingListItem, _ rhs: PendingListItem) -> Bool {
        let lhsDue = lhs.displayDueDate
        let rhsDue = rhs.displayDueDate

        if lhs.isOverdue != rhs.isOverdue {
            return lhs.isOverdue
        }

        if let leftDue = lhsDue, let rightDue = rhsDue,
           !Calendar.current.isDate(leftDue, equalTo: rightDue, toGranularity: .minute) {
            return leftDue < rightDue
        }

        return lhs.task.sortScore > rhs.task.sortScore
    }

    private func sortSectionDates(_ lhs: Date, _ rhs: Date, today: Date) -> Bool {
        let lhsIsPast = lhs < today
        let rhsIsPast = rhs < today

        if lhsIsPast != rhsIsPast {
            return lhsIsPast
        }

        if lhsIsPast && rhsIsPast {
            return lhs > rhs
        }

        return lhs < rhs
    }

    private func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return L("pending.section.today")
        }

        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func sectionSubtitle(for date: Date, calendar: Calendar) -> String? {
        let today = calendar.startOfDay(for: Date())
        if date < today {
            let days = calendar.dateComponents([.day], from: date, to: today).day ?? 0
            if days <= 0 { return nil }
            return days == 1 ? "Overdue, 1 day ago" : "Overdue, \(days) days ago"
        }

        let year = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: today)
        if year != currentYear {
            return date.formatted(.dateTime.year())
        }

        return date.formatted(.dateTime.weekday(.wide))
    }

    private func sectionIcon(for date: Date, calendar: Calendar) -> String {
        if date < calendar.startOfDay(for: Date()) {
            return "exclamationmark.triangle.fill"
        }

        if calendar.isDateInToday(date) {
            return "sun.max.fill"
        }

        return "calendar"
    }

    private func sectionTint(for date: Date, calendar: Calendar) -> Color {
        if date < calendar.startOfDay(for: Date()) {
            return .red
        }

        if calendar.isDateInToday(date) {
            return AppTheme.accent
        }

        return AppTheme.primary
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

        var seenKeys = Set(existingItems.compactMap { item -> String? in
            guard let dueDate = item.displayDueDate else { return nil }
            return projectionKey(taskID: item.task.id, date: dueDate, calendar: calendar)
        })

        var states = allTasks
            .filter { $0.isRecurring && !$0.isCompleted }
            .map { task in
                ProjectionState(
                    task: task,
                    cursor: max(task.dueDate ?? now, now),
                    emittedCount: 0,
                    exhausted: false
                )
            }

        var projected: [PendingListItem] = []

        while projected.count < Self.futurePreviewLimit,
              states.contains(where: { !$0.exhausted && $0.emittedCount < Self.maxProjectedItemsPerTask }) {
            var madeProgress = false

            for index in states.indices where projected.count < Self.futurePreviewLimit {
                guard !states[index].exhausted,
                      states[index].emittedCount < Self.maxProjectedItemsPerTask else {
                    continue
                }

                var attempts = 0
                var didEmit = false

                while attempts < 8,
                      let nextDate = nextRecurringDate(for: states[index].task, after: states[index].cursor, calendar: calendar) {
                    attempts += 1
                    states[index].cursor = nextDate

                    if nextDate > horizon {
                        states[index].exhausted = true
                        break
                    }

                    let key = projectionKey(taskID: states[index].task.id, date: nextDate, calendar: calendar)
                    guard !seenKeys.contains(key) else {
                        continue
                    }

                    seenKeys.insert(key)
                    states[index].emittedCount += 1
                    projected.append(PendingListItem(task: states[index].task, projectedDueDate: nextDate))
                    madeProgress = true
                    didEmit = true
                    break
                }

                if !didEmit && attempts == 0 {
                    states[index].exhausted = true
                }
            }

            if !madeProgress {
                break
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

private struct PendingDateSection: Identifiable {
    let date: Date?
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let items: [PendingListItem]

    var id: String {
        if let date {
            return String(date.timeIntervalSince1970)
        }
        return "someday"
    }
}

private struct ProjectionState {
    let task: TaskItem
    var cursor: Date
    var emittedCount: Int
    var exhausted: Bool
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

    var isOverdue: Bool {
        guard !isProjected, let dueDate = displayDueDate else { return false }
        let calendar = Calendar.current
        let endOfDueDateDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dueDate))!
        return Date() >= endOfDueDateDay
    }
}

private struct PendingSectionHeader: View {
    let section: PendingDateSection

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: section.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(section.tint)
                .frame(width: 22, height: 22)
                .background(section.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(section.title)
                .font(.headline.weight(.bold))
                .foregroundColor(.primary)

            if let subtitle = section.subtitle {
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)

            Text("\(section.items.count)")
                .font(.caption.weight(.bold))
                .foregroundColor(section.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(section.tint.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .textCase(nil)
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

        if item.isOverdue {
            return "from \(dueDate.formatted(.dateTime.day().month(.abbreviated)))"
        }

        if Calendar.current.isDateInToday(dueDate) {
            return dueDate.formatted(.dateTime.hour().minute())
        }

        return dueDate.formatted(.dateTime.day().month(.abbreviated))
    }

    private var overdueAgeLabel: String? {
        guard item.isOverdue, let dueDate = item.displayDueDate else { return nil }
        let calendar = Calendar.current
        let dueDay = calendar.startOfDay(for: dueDate)
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0
        if days <= 0 { return nil }
        return days == 1 ? "1d ago" : "\(days)d ago"
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
                        taskMetaBadge(text: dueLabel, icon: item.isOverdue ? "clock.badge.exclamationmark" : "calendar", tint: item.isOverdue ? .red : AppTheme.accent, compact: false)
                    }

                    if let overdueAgeLabel {
                        taskMetaBadge(text: overdueAgeLabel, icon: "exclamationmark.triangle.fill", tint: .red, compact: false)
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
