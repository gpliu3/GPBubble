//
//  CompletedTasksView.swift
//  GPBubble
//

import SwiftUI
import SwiftData

struct CompletedTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { $0.isCompleted },
           sort: \TaskItem.completedAt,
           order: .reverse)
    private var completedTasks: [TaskItem]

    @State private var selectedPeriod: TimePeriod = .week
    @State private var editingTask: TaskItem?
    @ObservedObject private var localizationManager = LocalizationManager.shared

    enum TimePeriod: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"

        var displayName: String {
            switch self {
            case .today: return L("completed.filter.today")
            case .week: return L("completed.filter.week")
            case .month: return L("completed.filter.month")
            case .all: return L("completed.filter.all")
            }
        }

        var startDate: Date? {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .today:
                return calendar.startOfDay(for: now)
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .all:
                return nil
            }
        }
    }

    private var filteredTasks: [TaskItem] {
        guard let startDate = selectedPeriod.startDate else {
            return completedTasks
        }
        return completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= startDate
        }
    }

    private var totalEffort: Double {
        filteredTasks.reduce(0) { $0 + $1.effort }
    }

    private var groupedTasks: [(String, [TaskItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTasks) { task -> String in
            guard let completedAt = task.completedAt else { return "Unknown" }

            if calendar.isDateInToday(completedAt) {
                return "Today"
            } else if calendar.isDateInYesterday(completedAt) {
                return "Yesterday"
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
                      completedAt >= weekAgo {
                return "This Week"
            } else {
                return completedAt.formatted(.dateTime.month(.abbreviated).day())
            }
        }

        // Sort by most recent first
        let order = ["Today", "Yesterday", "This Week"]
        return grouped.sorted { a, b in
            let aIndex = order.firstIndex(of: a.key) ?? Int.max
            let bIndex = order.firstIndex(of: b.key) ?? Int.max
            if aIndex != bIndex {
                return aIndex < bIndex
            }
            return a.key > b.key
        }
    }

    var body: some View {
        List {
            // Stats Section
            Section {
                statsCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Period Picker
            Section {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)

            // Completed Tasks
            if filteredTasks.isEmpty {
                Section {
                    emptyStateView
                }
            } else {
                ForEach(groupedTasks, id: \.0) { section, tasks in
                    Section(header: Text(section)) {
                        ForEach(tasks) { task in
                            CompletedTaskRow(task: task)
                                .contentShape(Rectangle())
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    editingTask = task
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteTask(task)
                                    } label: {
                                        Label(L("task.delete"), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        restoreTask(task)
                                    } label: {
                                        Label(L("completed.restore"), systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationTitle(L("completed.title"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
    }

    /// Format total minutes as hours and minutes
    private func formatTotalTime(_ minutes: Double) -> String {
        let totalMins = Int(minutes)
        if totalMins >= 60 {
            let hours = totalMins / 60
            let mins = totalMins % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
        return "\(totalMins)m"
    }

    private var statsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatBox(
                    title: L("completed.stats.tasks"),
                    value: "\(filteredTasks.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatBox(
                    title: L("completed.stats.time"),
                    value: formatTotalTime(totalEffort),
                    icon: "clock.fill",
                    color: .orange
                )
            }

            if !filteredTasks.isEmpty {
                let avgMinutes = totalEffort / Double(filteredTasks.count)
                Text(String(format: L("completed.stats.avg"), formatTotalTime(avgMinutes)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
        )
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text(L("completed.empty"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func deleteTask(_ task: TaskItem) {
        withAnimation {
            modelContext.delete(task)
        }
    }

    private func canRestore(_ task: TaskItem) -> Bool {
        // Check if task has a due date and if it's in the past
        if let dueDate = task.dueDate {
            let now = Date()
            return dueDate >= now
        }
        // No due date, can always restore
        return true
    }

    private func restoreTask(_ task: TaskItem) {
        withAnimation {
            task.undoComplete()
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.surface)
        )
    }
}

// MARK: - Completed Task Row

struct CompletedTaskRow: View {
    let task: TaskItem

    private var priorityColor: Color {
        switch task.priority {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(true, color: .secondary)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let completedAt = task.completedAt {
                        Label(completedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    if task.isRecurring, let desc = task.recurringDescription {
                        Label(desc, systemImage: "repeat")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Time effort badge
            Text(task.effortLabel)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(4)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(task.priorityLabel), \(task.effortLabel)")
    }
}

#Preview {
    NavigationStack {
        CompletedTasksView()
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
