//
//  ContentView.swift
//  BubbleTodo
//
//  Created by Gengpu Liu on 18/1/26.
//

import SwiftUI
import SwiftData
import UserNotifications

enum AppTheme {
    static let primary = Color(red: 0.11, green: 0.43, blue: 0.83)
    static let secondary = Color(red: 0.03, green: 0.65, blue: 0.62)
    static let accent = Color(red: 0.95, green: 0.62, blue: 0.27)

    static let backgroundTop = Color(red: 0.95, green: 0.98, blue: 1.0)
    static let backgroundBottom = Color(red: 0.90, green: 0.95, blue: 0.97)
    static let surface = Color.white.opacity(0.92)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted },
           sort: \TaskItem.createdAt)
    private var allTasks: [TaskItem]

    @State private var selectedTab = 0
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MainBubbleView()
            }
            .tabItem {
                Label(L("nav.bubbles"), systemImage: "bubble.fill")
            }
            .tag(0)

            NavigationStack {
                CompletedTasksView()
            }
            .tabItem {
                Label(L("nav.done"), systemImage: "checkmark.circle.fill")
            }
            .tag(1)

            NavigationStack {
                PastDueView()
            }
            .tabItem {
                Label("Past Due", systemImage: "exclamationmark.circle.fill")
            }
            .tag(2)

            SettingsView()
                .tabItem {
                    Label(L("nav.settings"), systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.primary)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Clear badge when app becomes active
                Task {
                    try? await UNUserNotificationCenter.current().setBadgeCount(0)
                }
                // Update notifications with current tasks when app becomes active
                updateNotifications()
            }
        }
        .onChange(of: allTasks.count) { _, _ in
            // Update notifications when task count changes
            updateNotifications()
        }
    }

    private func updateNotifications() {
        guard notificationManager.isAuthorized && notificationManager.notificationsEnabled else {
            return
        }

        // Filter to today's tasks only
        let todayTasks = allTasks.filter { $0.shouldShowToday }

        Task {
            await notificationManager.scheduleNotificationWithTasks(todayTasks)
        }
    }
}

struct PastDueView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted },
           sort: \TaskItem.createdAt)
    private var allTasks: [TaskItem]

    @State private var editingTask: TaskItem?

    private var sortedPastDueTasks: [TaskItem] {
        allTasks
            .filter { $0.shouldShowInPastDue }
            .sorted { $0.sortScore > $1.sortScore }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if sortedPastDueTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.secondary)

                    Text("No past due tasks")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(AppTheme.surface)
                )
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        BubbleLayoutView(
                            tasks: sortedPastDueTasks,
                            containerWidth: geometry.size.width,
                            containerHeight: geometry.size.height,
                            dayProgress: 1.0,
                            onTap: { task in
                                completeTask(task)
                            },
                            onLongPress: { task in
                                editingTask = task
                            }
                        )
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("Past Due")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
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

#Preview {
    ContentView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
