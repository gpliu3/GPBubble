//
//  AddTaskSheet.swift
//  BubbleTodo
//

import SwiftUI
import SwiftData

struct AddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var priority = 3
    @State private var effort: Double = 15.0 // Default to 15 minutes
    @State private var hasDueDate = true // Default to having a due date (one-off task)
    @State private var dueDate = Date() // Default to today + current time
    @State private var dueDateType: DueDateType = .before
    @State private var isRecurring = false
    @State private var recurringInterval: RecurringInterval = .daily
    @State private var recurringCount = 1
    @State private var selectedWeekdays: Set<Weekday> = []
    @State private var useSpecificDays = false
    @State private var monthlyPattern: MonthlyPattern = .timesPerMonth
    @State private var monthlyDayOfMonth: Int = 1
    @State private var monthlyWeekNumber: WeekNumber = .first
    @State private var monthlyWeekday: Weekday = .monday
    @State private var hasRecurringTime = false // Whether recurring task has specific time
    @State private var recurringTime = Date() // Time for recurring task occurrence
    @ObservedObject private var localizationManager = LocalizationManager.shared

    private var priorityOptions: [(value: Int, label: String, color: Color)] {
        [
            (value: 1, label: L("priority.low"), color: Color.green),
            (value: 2, label: L("priority.medium"), color: Color.yellow),
            (value: 3, label: L("priority.high"), color: Color.orange),
            (value: 4, label: L("priority.urgent"), color: Color.red),
            (value: 5, label: L("priority.critical"), color: Color.purple)
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section {
                    TextField(L("task.placeholder"), text: $title)
                        .font(.body)
                } header: {
                    Text(L("task.title"))
                        .textCase(nil)
                }

                // Priority Section
                Section {
                    Picker(L("priority.title"), selection: $priority) {
                        ForEach(priorityOptions, id: \.value) { option in
                            HStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 12, height: 12)
                                Text(option.label)
                            }
                            .tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)

                    // Visual priority indicator
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= priority ? priorityColor(for: priority) : Color.gray.opacity(0.3))
                                .frame(minWidth: 28, minHeight: 28)
                                .frame(maxWidth: 36, maxHeight: 36)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        priority = level
                                    }
                                }
                                .accessibilityLabel(String(format: L("accessibility.priority.indicator"), level))
                                .accessibilityAddTraits(level == priority ? [.isButton, .isSelected] : .isButton)
                        }
                        Spacer()
                        Text(priorityLabel(for: priority))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .contain)
                } header: {
                    Text(L("priority.title"))
                } footer: {
                    Text(L("priority.footer"))
                }

                // Effort Section (Time-based)
                Section {
                    VStack(spacing: 8) {
                        // First row: 1 min, 5 min, 15 min
                        HStack(spacing: 8) {
                            ForEach(Array(TaskItem.effortOptions.prefix(3)), id: \.value) { option in
                                Button {
                                    effort = option.value
                                } label: {
                                    Text(option.label)
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(effort == option.value ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(effort == option.value ? .white : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.label)
                                .accessibilityAddTraits(effort == option.value ? [.isButton, .isSelected] : .isButton)
                            }
                        }

                        // Second row: 30 min, 1 hour, 2 hours
                        HStack(spacing: 8) {
                            ForEach(Array(TaskItem.effortOptions.dropFirst(3)), id: \.value) { option in
                                Button {
                                    effort = option.value
                                } label: {
                                    Text(option.label)
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(effort == option.value ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(effort == option.value ? .white : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.label)
                                .accessibilityAddTraits(effort == option.value ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                    }
                } header: {
                    Text(L("effort.title"))
                } footer: {
                    Text(L("effort.footer"))
                }

                // Task Type Section - Two bordered boxes
                Section {
                    VStack(spacing: 12) {
                        // One-off Task Box
                        TaskTypeBox(
                            isSelected: hasDueDate,
                            title: L("task.oneoff"),
                            icon: "calendar",
                            accentColor: .blue
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hasDueDate = true
                                isRecurring = false
                            }
                        } content: {
                            if hasDueDate {
                                VStack(spacing: 12) {
                                    // Date type selector
                                    HStack(spacing: 8) {
                                        ForEach([DueDateType.before, DueDateType.on], id: \.self) { type in
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    dueDateType = type
                                                }
                                            } label: {
                                                Text(type.displayName)
                                                    .font(.subheadline.weight(.medium))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(dueDateType == type ?
                                                                  (type == .on ? Color.green : Color.orange) :
                                                                    Color.gray.opacity(0.15))
                                                    )
                                                    .foregroundColor(dueDateType == type ? .white : .primary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    // Date picker
                                    DatePicker(
                                        L("duedate.title"),
                                        selection: $dueDate,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .datePickerStyle(.compact)

                                    // Description
                                    Text(dueDateType.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.top, 8)
                            }
                        }

                        // Recurring Task Box
                        TaskTypeBox(
                            isSelected: isRecurring,
                            title: L("recurring.toggle"),
                            icon: "repeat",
                            accentColor: .purple
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isRecurring = true
                                hasDueDate = false
                            }
                        } content: {
                            if isRecurring {
                                VStack(spacing: 12) {
                                    // Repeat interval picker
                                    Picker(L("recurring.repeat"), selection: $recurringInterval) {
                                        ForEach(RecurringInterval.allCases, id: \.self) { interval in
                                            Text(interval.displayName).tag(interval)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    // Weekly options
                                    if recurringInterval == .weekly {
                                        Toggle(L("recurring.specificdays"), isOn: $useSpecificDays.animation())
                                            .font(.subheadline)

                                        if useSpecificDays {
                                            WeekdayPicker(selectedDays: $selectedWeekdays)
                                        } else {
                                            Stepper(String(format: L("recurring.timesperweek"), recurringCount), value: $recurringCount, in: 1...7)
                                                .font(.subheadline)
                                        }
                                    }

                                    // Monthly options
                                    if recurringInterval == .monthly {
                                        MonthlyPatternPicker(
                                            pattern: $monthlyPattern,
                                            dayOfMonth: $monthlyDayOfMonth,
                                            weekNumber: $monthlyWeekNumber,
                                            weekday: $monthlyWeekday,
                                            timesPerMonth: $recurringCount
                                        )
                                    }

                                    Divider()

                                    // Time picker for recurring tasks
                                    Toggle(L("task.specifictime"), isOn: $hasRecurringTime.animation())
                                        .font(.subheadline)

                                    if hasRecurringTime {
                                        DatePicker(
                                            L("task.time"),
                                            selection: $recurringTime,
                                            displayedComponents: .hourAndMinute
                                        )
                                        .font(.subheadline)
                                    }

                                    // Description
                                    Text(L("recurring.footer"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                } header: {
                    Text(L("task.schedule"))
                        .textCase(nil)
                }
            }
            .listRowSpacing(8)
            .navigationTitle(L("task.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("task.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L("task.save")) {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .orange
        }
    }

    private func priorityLabel(for priority: Int) -> String {
        priorityOptions.first { $0.value == priority }?.label ?? "High"
    }

    private func saveTask() {
        let weeklyDays: [Int] = useSpecificDays && recurringInterval == .weekly
            ? selectedWeekdays.map { $0.rawValue }
            : []

        // For recurring tasks, set initial dueDate based on hasRecurringTime
        // For one-time tasks, use the user-selected due date
        let taskDueDate: Date?
        let taskDueDateType: DueDateType

        if isRecurring {
            // Recurring tasks
            if hasRecurringTime {
                // User specified a time - combine today's date with selected time
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: recurringTime)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                taskDueDate = calendar.date(from: dateComponents) ?? Date()
            } else {
                // No specific time - start today
                taskDueDate = Date()
            }
            taskDueDateType = .on // Recurring tasks always use "on" type
        } else {
            // One-off tasks
            taskDueDate = hasDueDate ? dueDate : nil
            taskDueDateType = dueDateType
        }

        let newTask = TaskItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            effort: effort,
            dueDate: taskDueDate,
            dueDateType: taskDueDateType,
            isRecurring: isRecurring,
            recurringInterval: isRecurring ? recurringInterval : nil,
            recurringCount: recurringCount,
            weeklyDays: weeklyDays,
            monthlyPattern: isRecurring && recurringInterval == .monthly ? monthlyPattern : nil,
            monthlyDayOfMonth: monthlyDayOfMonth,
            monthlyWeekNumber: monthlyWeekNumber.rawValue,
            monthlyWeekday: monthlyWeekday.rawValue
        )

        modelContext.insert(newTask)

        // Play satisfying sound when adding task
        SoundManager.playSuccessWithHaptic()

        dismiss()
    }
}

// MARK: - Weekday Picker

struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("recurring.selectdays"))
                .font(.caption)
                .foregroundColor(.secondary)

            // Use flexible grid for better Zoom mode support
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Weekday.allCases) { day in
                    Button {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    } label: {
                        Text(String(day.shortName.prefix(1)))
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 36, minHeight: 36)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(selectedDays.contains(day) ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.fullName)
                    .accessibilityAddTraits(selectedDays.contains(day) ? [.isButton, .isSelected] : .isButton)
                }
            }

            if !selectedDays.isEmpty {
                Text(selectedDays.sorted { $0.rawValue < $1.rawValue }.map { $0.shortName }.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Task Type Box

struct TaskTypeBox<Content: View>: View {
    let isSelected: Bool
    let title: String
    let icon: String
    let accentColor: Color
    let onSelect: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with radio button
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    // Radio button indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? accentColor : Color.gray.opacity(0.4), lineWidth: 2)
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 12, height: 12)
                        }
                    }

                    // Icon
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                        .foregroundColor(isSelected ? accentColor : .secondary)
                        .frame(width: 24)

                    // Title
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(isSelected ? .primary : .secondary)

                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)

            // Content (shown when selected)
            if isSelected {
                content
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? accentColor.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
    }
}

// MARK: - Monthly Pattern Picker

struct MonthlyPatternPicker: View {
    @Binding var pattern: MonthlyPattern
    @Binding var dayOfMonth: Int
    @Binding var weekNumber: WeekNumber
    @Binding var weekday: Weekday
    @Binding var timesPerMonth: Int

    var body: some View {
        VStack(spacing: 12) {
            // Pattern type selector
            Picker(L("monthly.pattern.title"), selection: $pattern.animation()) {
                ForEach(MonthlyPattern.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.menu)

            // Pattern-specific options
            switch pattern {
            case .dayOfMonth:
                DayOfMonthPicker(selectedDay: $dayOfMonth)

            case .nthWeekday:
                NthWeekdayPicker(weekNumber: $weekNumber, weekday: $weekday)

            case .timesPerMonth:
                Stepper(String(format: L("recurring.timespermonth"), timesPerMonth), value: $timesPerMonth, in: 1...30)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Day of Month Picker

struct DayOfMonthPicker: View {
    @Binding var selectedDay: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("monthly.day.select"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Grid of day buttons (7 columns) - flexible for Zoom mode
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(1...31, id: \.self) { day in
                    Button {
                        selectedDay = day
                    } label: {
                        Text("\(day)")
                            .font(.subheadline.weight(.medium))
                            .frame(minWidth: 32, minHeight: 32)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(selectedDay == day ? Color.purple : Color.gray.opacity(0.2))
                            .foregroundColor(selectedDay == day ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: L("monthly.day.format"), "\(day)"))
                    .accessibilityAddTraits(selectedDay == day ? [.isButton, .isSelected] : .isButton)
                }
            }

            // "Last day" option
            Button {
                selectedDay = 0
            } label: {
                HStack {
                    Image(systemName: selectedDay == 0 ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundColor(selectedDay == 0 ? .purple : .secondary)
                    Text(L("monthly.lastday"))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(selectedDay == 0 ? Color.purple.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("monthly.lastday"))
            .accessibilityAddTraits(selectedDay == 0 ? [.isButton, .isSelected] : .isButton)
        }
    }
}

// MARK: - Nth Weekday Picker

struct NthWeekdayPicker: View {
    @Binding var weekNumber: WeekNumber
    @Binding var weekday: Weekday

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Week number picker
            HStack {
                Text(L("monthly.weeknumber"))
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $weekNumber) {
                    ForEach(WeekNumber.allCases) { wn in
                        Text(wn.displayName).tag(wn)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Weekday picker - flexible grid for Zoom mode
            VStack(alignment: .leading, spacing: 8) {
                Text(L("monthly.weekday"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(Weekday.allCases) { day in
                        Button {
                            weekday = day
                        } label: {
                            Text(String(day.shortName.prefix(1)))
                                .font(.subheadline.weight(.semibold))
                                .frame(minWidth: 36, minHeight: 36)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(weekday == day ? Color.purple : Color.gray.opacity(0.2))
                                .foregroundColor(weekday == day ? .white : .primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(day.fullName)
                        .accessibilityAddTraits(weekday == day ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }

            // Summary text
            Text(String(format: L("monthly.summary"), weekNumber.displayName, weekday.fullName))
                .font(.subheadline)
                .foregroundColor(.purple)
        }
    }
}

#Preview {
    AddTaskSheet()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
