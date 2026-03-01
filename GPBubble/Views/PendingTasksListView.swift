//
//  PendingTasksListView.swift
//  GPBubble
//

import SwiftUI
import SwiftData

struct PendingTasksListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted },
           sort: \TaskItem.createdAt)
    private var allTasks: [TaskItem]

    @State private var editingTask: TaskItem?

    private var overdueTasks: [TaskItem] {
        allTasks
            .filter { $0.shouldShowInPastDue }
            .sorted { $0.sortScore > $1.sortScore }
    }

    private var todayTasks: [TaskItem] {
        allTasks
            .filter { !$0.shouldShowInPastDue && $0.shouldShowToday }
            .sorted { $0.sortScore > $1.sortScore }
    }

    private var upcomingTasks: [TaskItem] {
        allTasks
            .filter { task in
                guard !task.shouldShowInPastDue, !task.shouldShowToday else { return false }
                return task.dueDate != nil
            }
            .sorted { lhs, rhs in
                if let leftDueDate = lhs.dueDate, let rightDueDate = rhs.dueDate, leftDueDate != rightDueDate {
                    return leftDueDate < rightDueDate
                }
                return lhs.sortScore > rhs.sortScore
            }
    }

    private var somedayTasks: [TaskItem] {
        allTasks
            .filter { !$0.shouldShowInPastDue && $0.dueDate == nil }
            .sorted { $0.sortScore > $1.sortScore }
    }

    private var sections: [(title: String, icon: String, tasks: [TaskItem], tint: Color)] {
        [
            (L("pending.section.overdue"), "exclamationmark.triangle.fill", overdueTasks, .red),
            (L("pending.section.today"), "sun.max.fill", todayTasks, AppTheme.accent),
            (L("pending.section.upcoming"), "calendar", upcomingTasks, AppTheme.primary),
            (L("pending.section.someday"), "tray.fill", somedayTasks, AppTheme.secondary)
        ]
        .filter { !$0.tasks.isEmpty }
    }

    var body: some View {
        List {
            if sections.isEmpty {
                emptyStateView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(sections, id: \.title) { section in
                    Section {
                        ForEach(section.tasks) { task in
                            PendingTaskRow(task: task)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingTask = task
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        completeTask(task)
                                    } label: {
                                        Label(L("pending.complete"), systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(AppTheme.secondary)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
        .background(
            LinearGradient(
                colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
}

private struct PendingTaskRow: View {
    let task: TaskItem

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
        guard let dueDate = task.dueDate else { return nil }

        if task.shouldShowInPastDue {
            return L("pending.section.overdue")
        }

        if Calendar.current.isDateInToday(dueDate) {
            return dueDate.formatted(.dateTime.hour().minute())
        }

        return dueDate.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(priorityColor)
                .frame(width: 8, height: 48)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(task.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(3)

                    Spacer(minLength: 0)

                    Text(task.priorityLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(priorityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(priorityColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    taskMetaBadge(text: task.effortLabel, icon: "timer", tint: AppTheme.primary)

                    if let dueLabel {
                        taskMetaBadge(text: dueLabel, icon: "calendar", tint: task.shouldShowInPastDue ? .red : AppTheme.accent)
                    }

                    if task.isRecurring {
                        taskMetaBadge(text: L("recurring.toggle"), icon: "repeat", tint: AppTheme.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func taskMetaBadge(text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
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
