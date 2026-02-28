//
//  EditTaskSheet.swift
//  BubbleTodo
//

import SwiftUI
import SwiftData

struct EditTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var task: TaskItem

    @State private var title: String
    @State private var priority: Int
    @State private var effort: Double
    @State private var customHours: Int
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var dueDateType: DueDateType
    @State private var isRecurring: Bool
    @State private var recurringInterval: RecurringInterval
    @State private var recurringCount: Int
    @State private var selectedWeekdays: Set<Weekday>
    @State private var useSpecificDays: Bool
    @State private var monthlyPattern: MonthlyPattern
    @State private var monthlyDayOfMonth: Int
    @State private var monthlyWeekNumber: WeekNumber
    @State private var monthlyWeekday: Weekday
    @State private var hasRecurringTime: Bool
    @State private var recurringTime: Date
    @State private var showingDeleteConfirmation = false
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

    /// Explanation of why the urgency weight increased
    private var urgencyExplanation: String {
        let now = Date()

        if let dueDate = task.dueDate {
            if now > dueDate {
                // Overdue
                let hoursOverdue = now.timeIntervalSince(dueDate) / 3600
                if hoursOverdue < 24 {
                    return L("info.urgency.overdue.hours")
                } else {
                    let days = Int(hoursOverdue / 24)
                    return String(format: L("info.urgency.overdue.days"), days)
                }
            } else if task.effectiveDueDateType == .before {
                let hoursUntilDue = dueDate.timeIntervalSince(now) / 3600
                if hoursUntilDue < 24 {
                    return L("info.urgency.due.today")
                } else if hoursUntilDue < 72 {
                    return L("info.urgency.due.soon")
                }
            }
        } else {
            // No due date - age-based
            let hoursSinceCreation = now.timeIntervalSince(task.createdAt) / 3600
            let days = Int(hoursSinceCreation / 24)
            return String(format: L("info.urgency.age"), days)
        }

        return ""
    }

    init(task: TaskItem) {
        self.task = task
        _title = State(initialValue: task.title)
        _priority = State(initialValue: task.priority)
        _effort = State(initialValue: task.effort)
        let effortHours = max(Int(task.effort.rounded()) / 60, 1)
        _customHours = State(initialValue: min(effortHours, 12))
        _hasDueDate = State(initialValue: task.dueDate != nil && !task.isRecurring)
        _dueDate = State(initialValue: task.dueDate ?? Date())
        _dueDateType = State(initialValue: task.effectiveDueDateType)
        _isRecurring = State(initialValue: task.isRecurring)
        _recurringInterval = State(initialValue: task.recurringInterval ?? .daily)
        _recurringCount = State(initialValue: task.recurringCount)
        _selectedWeekdays = State(initialValue: Set(task.weeklyDays.compactMap { Weekday(rawValue: $0) }))
        _useSpecificDays = State(initialValue: !task.weeklyDays.isEmpty)
        _monthlyPattern = State(initialValue: task.monthlyPattern ?? .timesPerMonth)
        _monthlyDayOfMonth = State(initialValue: task.monthlyDayOfMonth)
        _monthlyWeekNumber = State(initialValue: WeekNumber(rawValue: task.monthlyWeekNumber) ?? .first)
        _monthlyWeekday = State(initialValue: Weekday(rawValue: task.monthlyWeekday) ?? .monday)
        _hasRecurringTime = State(initialValue: task.isRecurring && task.dueDate != nil)
        _recurringTime = State(initialValue: task.dueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section {
                    TextField(L("task.placeholder"), text: $title)
                        .font(.title3.weight(.medium))
                        .textFieldStyle(.plain)
                        .padding(18)
                        .taskEditorCard()
                } header: {
                    Text(L("task.title"))
                        .textCase(nil)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

                // Priority Section
                Section {
                    VStack(alignment: .leading, spacing: 18) {
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

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { level in
                                    Circle()
                                        .fill(level <= priority ? priorityColor(for: priority) : Color.gray.opacity(0.18))
                                        .frame(minWidth: 30, minHeight: 30)
                                        .frame(maxWidth: 38, maxHeight: 38)
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
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(priorityColor(for: priority))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(priorityColor(for: priority).opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            Text(L("priority.footer"))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .contain)
                    }
                    .padding(18)
                    .taskEditorCard()
                } header: {
                    Text(L("priority.title"))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

                // Effort Section (Time-based)
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(TaskItem.effortOptions, id: \.value) { option in
                                effortOptionButton(
                                    label: option.label,
                                    value: option.value
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L("effort.customhours"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)

                            Picker(L("effort.customhours"), selection: $customHours) {
                                ForEach(1...12, id: \.self) { value in
                                    Text("\(value)h").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .clipped()
                            .onChange(of: customHours) { _, newValue in
                                effort = Double(newValue * 60)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(effort >= 180 && Int(effort.rounded()) % 60 == 0 ? AppTheme.secondary.opacity(0.12) : Color(.secondarySystemBackground))
                        )

                        Text(L("effort.footer"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(18)
                    .taskEditorCard()
                } header: {
                    Text(L("effort.title"))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

                // Task Type Section - Two bordered boxes
                Section {
                    VStack(spacing: 12) {
                        // One-off Task Box
                        TaskTypeBox(
                            isSelected: hasDueDate,
                            title: L("task.oneoff"),
                            icon: "calendar",
                            accentColor: AppTheme.primary
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
                                                    .padding(.vertical, 10)
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(dueDateType == type ?
                                                                  (type == .on ? AppTheme.secondary : AppTheme.accent) :
                                                                    Color(.secondarySystemBackground))
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
                            accentColor: AppTheme.secondary
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
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

                // Task Info Section
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledContent(L("info.created")) {
                            Text(task.createdAt.formatted(.dateTime.month().day().hour().minute()))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if task.effectiveWeight > 1.0 {
                            VStack(alignment: .leading, spacing: 8) {
                                LabeledContent(L("info.urgency")) {
                                    Text(String(format: "%.1fx", task.effectiveWeight))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(AppTheme.accent)
                                }

                                Text(urgencyExplanation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(18)
                    .taskEditorCard()
                } header: {
                    Text(L("info.title"))
                } footer: {
                    if task.effectiveWeight > 1.0 {
                        Text(L("info.urgency.footer"))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

                // Delete Section
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label(L("task.delete"), systemImage: "trash")
                            Spacer()
                        }
                        .padding(18)
                        .taskEditorCard()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            }
            .listRowSpacing(8)
            .listSectionSpacing(18)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .tint(AppTheme.primary)
            .navigationTitle(L("task.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("task.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L("task.save")) {
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                L("task.delete.confirm"),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L("task.delete"), role: .destructive) {
                    deleteTask()
                }
                Button(L("task.cancel"), role: .cancel) {}
            } message: {
                Text(L("task.delete.message"))
            }
        }
        .onAppear {
            syncCustomHoursFromEffort()
        }
        .onChange(of: effort) { _, _ in
            syncCustomHoursFromEffort()
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

    @ViewBuilder
    private func effortOptionButton(label: String, value: Double) -> some View {
        Button {
            effort = value
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(effort == value ? AppTheme.primary : Color(.secondarySystemBackground))
                )
                .foregroundColor(effort == value ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(effort == value ? [.isButton, .isSelected] : .isButton)
    }

    private func syncCustomHoursFromEffort() {
        let roundedEffort = Int(effort.rounded())
        guard roundedEffort >= 60, roundedEffort % 60 == 0 else { return }
        customHours = min(max(roundedEffort / 60, 1), 12)
    }

    private func saveChanges() {
        let weeklyDays: [Int] = useSpecificDays && recurringInterval == .weekly
            ? selectedWeekdays.map { $0.rawValue }
            : []

        // For recurring tasks, set dueDate based on hasRecurringTime
        // For one-time tasks, use the user-selected due date
        let taskDueDate: Date?
        let taskDueDateType: DueDateType

        if isRecurring {
            // Recurring tasks
            if hasRecurringTime {
                // User specified a time - combine today's date with selected time
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: recurringTime)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: task.dueDate ?? Date())
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                taskDueDate = calendar.date(from: dateComponents) ?? (task.dueDate ?? Date())
            } else {
                // No specific time - keep existing or start today
                taskDueDate = task.dueDate ?? Date()
            }
            taskDueDateType = .on // Recurring tasks always use "on" type
        } else {
            // One-off tasks
            taskDueDate = hasDueDate ? dueDate : nil
            taskDueDateType = dueDateType
        }

        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.priority = priority
        task.effort = effort
        task.dueDate = taskDueDate
        task.dueDateType = taskDueDateType
        task.isRecurring = isRecurring
        task.recurringInterval = isRecurring ? recurringInterval : nil
        task.recurringCount = recurringCount
        task.weeklyDays = weeklyDays
        task.monthlyPattern = isRecurring && recurringInterval == .monthly ? monthlyPattern : nil
        task.monthlyDayOfMonth = monthlyDayOfMonth
        task.monthlyWeekNumber = monthlyWeekNumber.rawValue
        task.monthlyWeekday = monthlyWeekday.rawValue

        // Play subtle success sound
        SoundManager.playSuccessWithHaptic()

        dismiss()
    }

    private func deleteTask() {
        modelContext.delete(task)
        dismiss()
    }
}

#Preview {
    let task = TaskItem(title: "Sample Task", priority: 3)
    return EditTaskSheet(task: task)
        .modelContainer(for: TaskItem.self, inMemory: true)
}
