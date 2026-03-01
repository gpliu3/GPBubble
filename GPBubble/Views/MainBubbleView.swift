//
//  MainBubbleView.swift
//  GPBubble
//

import SwiftUI
import SwiftData
import Combine
import UIKit

struct MainBubbleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted },
           sort: \TaskItem.createdAt)
    private var allTasks: [TaskItem]

    @State private var showingAddSheet = false
    @State private var editingTask: TaskItem?
    @State private var currentTime = Date()
    @ObservedObject private var localizationManager = LocalizationManager.shared

    // Date navigation state
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var dragOffset: CGFloat = 0
    @State private var followsToday = true
    @State private var lastObservedDayStart = Calendar.current.startOfDay(for: Date())

    // Undo state
    @State private var recentlyCompletedTask: TaskItem?
    @State private var createdRecurringTask: TaskItem?
    @State private var showUndoToast = false
    @State private var undoTimer: Timer?

    // Timer for updating time-based positioning
    let timeUpdateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private var isViewingToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    // Filter tasks for the selected date
    private var tasksForSelectedDate: [TaskItem] {
        if isViewingToday {
            return allTasks.filter { $0.shouldShowToday }
        } else {
            return allTasks.filter { $0.shouldShowOnDate(selectedDate) }
        }
    }

    // Sort tasks by priority/urgency (highest sortScore first = top)
    private var sortedTasks: [TaskItem] {
        tasksForSelectedDate.sorted { $0.sortScore > $1.sortScore }
    }

    // Day progress: 0.0 at 6 AM, 1.0 at 10 PM
    private var dayProgress: Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)

        let currentMinutes = Double(hour * 60 + minute)
        let startMinutes: Double = 6 * 60  // 6 AM
        let endMinutes: Double = 22 * 60   // 10 PM

        let progress = (currentMinutes - startMinutes) / (endMinutes - startMinutes)
        return min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            // Background gradient - changes with time of day
            LinearGradient(
                gradient: Gradient(colors: [
                    AppTheme.backgroundTop,
                    isViewingToday && dayProgress > 0.7 ? AppTheme.accent.opacity(0.20) : AppTheme.backgroundBottom
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Date navigation header - always at top
                DateNavigationHeader(
                    selectedDate: $selectedDate,
                    showingDatePicker: $showingDatePicker,
                    onPrevious: { navigateDate(by: -1) },
                    onNext: { navigateDate(by: 1) },
                    onToday: { goToToday() }
                )

                // Main content with swipe gesture
                ZStack {
                    if tasksForSelectedDate.isEmpty {
                        emptyStateView
                    } else {
                        bubbleGridView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width * 0.3
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            withAnimation(.easeOut(duration: 0.2)) {
                                if value.translation.width > threshold {
                                    navigateDate(by: -1)
                                } else if value.translation.width < -threshold {
                                    navigateDate(by: 1)
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Floating add button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                }
            }
            .padding()
            .padding(.bottom, showUndoToast ? 60 : 0)

            // Undo toast
            if showUndoToast, let completedTask = recentlyCompletedTask {
                VStack {
                    Spacer()
                    UndoToastView(
                        taskTitle: completedTask.title,
                        onUndo: {
                            undoCompletion()
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(L("main.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSheet) {
            AddTaskSheet()
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .onReceive(timeUpdateTimer) { _ in
            currentTime = Date()
            handleDayChangeIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            handleDayChangeIfNeeded(forceRefresh: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            handleDayChangeIfNeeded(forceRefresh: true)
        }
        .onAppear {
            followsToday = isViewingToday
            lastObservedDayStart = calendar.startOfDay(for: Date())
        }
        .onChange(of: selectedDate) { _, newDate in
            followsToday = calendar.isDateInToday(newDate)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handleDayChangeIfNeeded(forceRefresh: true)
            }
        }
    }

    private func navigateDate(by days: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
                selectedDate = newDate
            }
            followsToday = calendar.isDateInToday(selectedDate)
        }
    }

    private func goToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = Date()
            followsToday = true
        }
    }

    private func handleDayChangeIfNeeded(forceRefresh: Bool = false) {
        let todayStart = calendar.startOfDay(for: Date())
        let didDayChange = todayStart != lastObservedDayStart

        guard didDayChange || forceRefresh else { return }
        lastObservedDayStart = todayStart

        if followsToday {
            selectedDate = Date()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: isViewingToday ? "bubble.left.and.bubble.right" : "calendar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(isViewingToday ? L("main.empty.title") : L("date.notasks"))
                .font(.title3)
                .foregroundColor(.secondary)

            if isViewingToday {
                Text(L("main.empty.subtitle"))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.surface)
        )
    }

    private var bubbleGridView: some View {
        GeometryReader { geometry in
            ScrollView {
                BubbleLayoutView(
                    tasks: sortedTasks,
                    containerWidth: geometry.size.width,
                    containerHeight: geometry.size.height,
                    dayProgress: dayProgress,
                    onTap: { task in
                        completeTask(task)
                    },
                    onLongPress: { task in
                        editingTask = task
                    }
                )
                .padding(.bottom, 100) // Space for add button
            }
        }
    }

    private var addButton: some View {
        Button(action: {
            showingAddSheet = true
        }) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [AppTheme.secondary, AppTheme.primary]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: AppTheme.primary.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel(L("accessibility.add.task"))
    }

    private func completeTask(_ task: TaskItem) {
        // Cancel any existing undo timer
        undoTimer?.invalidate()

        withAnimation {
            task.markComplete()

            // Store for undo
            recentlyCompletedTask = task
            createdRecurringTask = nil

            // If recurring, create the next instance
            if let nextTask = task.createNextRecurringTask() {
                modelContext.insert(nextTask)
                createdRecurringTask = nextTask
            }

            // Show undo toast
            showUndoToast = true
        }

        // Start 3 second timer
        undoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation {
                showUndoToast = false
                recentlyCompletedTask = nil
                createdRecurringTask = nil
            }
        }
    }

    private func undoCompletion() {
        undoTimer?.invalidate()

        withAnimation {
            // Undo the task completion
            recentlyCompletedTask?.undoComplete()

            // Remove the recurring task if one was created
            if let recurringTask = createdRecurringTask {
                modelContext.delete(recurringTask)
            }

            showUndoToast = false
            recentlyCompletedTask = nil
            createdRecurringTask = nil
        }
    }
}

// MARK: - Day Progress Indicator

struct DayProgressIndicator: View {
    let progress: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: progress < 0.5 ? "sun.rise.fill" : "sun.max.fill")
                .foregroundColor(progress > 0.7 ? .orange : .yellow)
                .font(.caption)

            Text("\(Int(progress * 100))%")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Undo Toast View

struct UndoToastView: View {
    let taskTitle: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(.green)

            Text(String(format: L("main.completed"), taskTitle))
                .font(.callout)
                .lineLimit(1)

            Spacer()

            Button(action: onUndo) {
                Text(L("main.undo"))
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Bubble Layout View

struct BubbleLayoutView: View {
    let tasks: [TaskItem]
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let dayProgress: Double
    let onTap: (TaskItem) -> Void
    let onLongPress: (TaskItem) -> Void

    // Morning offset: bubbles start lower, rise throughout the day
    // At 0% progress (morning): offset = maxOffset (bubbles at bottom)
    // At 100% progress (evening): offset = 0 (bubbles at top)
    private var verticalOffset: CGFloat {
        let maxOffset: CGFloat = max(containerHeight * 0.4, 200)
        return maxOffset * (1 - dayProgress)
    }

    // Cache bubble diameters to avoid repeated calculations
    private var cachedDiameters: [UUID: CGFloat] {
        var cache: [UUID: CGFloat] = [:]
        for task in tasks {
            cache[task.id] = Self.bubbleDiameter(for: task)
        }
        return cache
    }

    // Pre-calculate layout once per render
    private var layoutData: (positions: [CGPoint], totalHeight: CGFloat) {
        calculateLayout()
    }

    var body: some View {
        let layout = layoutData

        ZStack(alignment: .top) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                if index < layout.positions.count {
                    BubbleView(
                        task: task,
                        onTap: { onTap(task) },
                        onLongPress: { onLongPress(task) }
                    )
                    .position(layout.positions[index])
                }
            }
        }
        .frame(width: containerWidth, height: layout.totalHeight)
        .offset(y: verticalOffset)
        .animation(.easeInOut(duration: 1.0), value: dayProgress)
    }

    // Static method to calculate diameter - no self reference needed
    private static func bubbleDiameter(for task: TaskItem) -> CGFloat {
        let baseSize: CGFloat = 62
        let scaleFactor: CGFloat = 9
        let size = baseSize + CGFloat(task.bubbleSize) * scaleFactor
        return min(max(size, 65), 165)
    }

    // Combined layout calculation - positions and height in one pass
    private func calculateLayout() -> (positions: [CGPoint], totalHeight: CGFloat) {
        var positions: [CGPoint] = []
        var currentY: CGFloat = 20
        var currentRowBubbles: [(id: UUID, diameter: CGFloat)] = []
        var currentRowWidth: CGFloat = 0
        let padding: CGFloat = 16
        let availableWidth = containerWidth - (padding * 2)
        let diameters = cachedDiameters

        for task in tasks {
            let diameter = diameters[task.id] ?? Self.bubbleDiameter(for: task)
            let bubbleWidth = diameter + 8

            // Check if bubble fits in current row
            if currentRowWidth + bubbleWidth > availableWidth && !currentRowBubbles.isEmpty {
                // Finalize current row - center it
                let rowHeight = currentRowBubbles.map { $0.diameter }.max() ?? 0
                let totalRowWidth = currentRowBubbles.reduce(0) { $0 + $1.diameter + 8 }
                var xOffset = (containerWidth - totalRowWidth) / 2

                for bubble in currentRowBubbles {
                    positions.append(CGPoint(
                        x: xOffset + bubble.diameter / 2,
                        y: currentY + rowHeight / 2
                    ))
                    xOffset += bubble.diameter + 8
                }

                // Start new row
                currentY += rowHeight + 16
                currentRowBubbles = []
                currentRowWidth = 0
            }

            currentRowBubbles.append((id: task.id, diameter: diameter))
            currentRowWidth += bubbleWidth
        }

        // Finalize last row
        if !currentRowBubbles.isEmpty {
            let rowHeight = currentRowBubbles.map { $0.diameter }.max() ?? 0
            let totalRowWidth = currentRowBubbles.reduce(0) { $0 + $1.diameter + 8 }
            var xOffset = (containerWidth - totalRowWidth) / 2

            for bubble in currentRowBubbles {
                positions.append(CGPoint(
                    x: xOffset + bubble.diameter / 2,
                    y: currentY + rowHeight / 2
                ))
                xOffset += bubble.diameter + 8
            }
            currentY += rowHeight
        }

        return (positions, currentY + 100)
    }
}

// MARK: - Date Navigation Header

struct DateNavigationHeader: View {
    @Binding var selectedDate: Date
    @Binding var showingDatePicker: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var isTomorrow: Bool {
        calendar.isDateInTomorrow(selectedDate)
    }

    private var isYesterday: Bool {
        calendar.isDateInYesterday(selectedDate)
    }

    private var dateLabel: String {
        if isToday {
            return L("date.today")
        } else if isTomorrow {
            return L("date.tomorrow")
        } else if isYesterday {
            return L("date.yesterday")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    private var fullDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Previous day button
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            Spacer()

            // Date display - tappable to show picker
            Button(action: { showingDatePicker = true }) {
                VStack(spacing: 2) {
                    Text(dateLabel)
                        .font(.headline)
                        .foregroundColor(isToday ? .primary : .blue)

                    if !isToday && !isTomorrow && !isYesterday {
                        Text(fullDateLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Next day button
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            // Today button (only show when not viewing today)
            if !isToday {
                Button(action: onToday) {
                    Text(L("date.today.short"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.95))
        .animation(.easeInOut(duration: 0.2), value: isToday)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    @State private var tempDate: Date

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    L("date.select"),
                    selection: $tempDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle(L("date.select"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("task.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("date.go")) {
                        selectedDate = tempDate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        MainBubbleView()
    }
    .modelContainer(for: TaskItem.self, inMemory: true)
}
