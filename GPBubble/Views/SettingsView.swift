//
//  SettingsView.swift
//  GPBubble
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var showingPermissionAlert = false

    /// App version from bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Notifications Section
                Section {
                    Toggle(L("settings.notifications.enable"), isOn: $notificationManager.notificationsEnabled)
                        .onChange(of: notificationManager.notificationsEnabled) { _, newValue in
                            if newValue && !notificationManager.isAuthorized {
                                Task {
                                    await notificationManager.requestAuthorization()
                                    if !notificationManager.isAuthorized {
                                        showingPermissionAlert = true
                                        notificationManager.notificationsEnabled = false
                                    }
                                }
                            }
                        }

                    if notificationManager.notificationsEnabled {
                        Picker(L("settings.notifications.frequency"), selection: $notificationManager.numberOfReminders) {
                            Text(String(format: L("settings.notifications.times"), 1)).tag(1)
                            Text(String(format: L("settings.notifications.times"), 2)).tag(2)
                            Text(String(format: L("settings.notifications.times"), 3)).tag(3)
                            Text(String(format: L("settings.notifications.times"), 4)).tag(4)
                        }

                        // Time pickers for each reminder
                        ForEach(0..<notificationManager.numberOfReminders, id: \.self) { index in
                            if index < notificationManager.reminderTimes.count {
                                DatePicker(
                                    String(format: L("settings.notifications.reminder"), index + 1),
                                    selection: Binding(
                                        get: { notificationManager.reminderTimes[index] },
                                        set: { newValue in
                                            var times = notificationManager.reminderTimes
                                            times[index] = newValue
                                            notificationManager.reminderTimes = times
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                            }
                        }
                    }
                } header: {
                    Text(L("settings.notifications"))
                } footer: {
                    if notificationManager.notificationsEnabled {
                        Text(L("settings.notifications.footer"))
                    }
                }

                // Appearance Section
                Section {
                    Picker(L("settings.language"), selection: $localizationManager.currentLanguage) {
                        Text(L("settings.language.system")).tag("system")
                        Text("English").tag("en")
                        Text("简体中文").tag("zh-Hans")
                        Text("繁體中文").tag("zh-Hant")
                        Text("日本語").tag("ja")
                        Text("한국어").tag("ko")
                        Text("Español").tag("es")
                        Text("Français").tag("fr")
                        Text("Deutsch").tag("de")
                        Text("Português (Brasil)").tag("pt-BR")
                    }
                } header: {
                    Text(L("settings.appearance"))
                }

                // About Section
                Section {
                    HStack {
                        Text(L("settings.version"))
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }

                    // Privacy Policy link
                    Link(destination: URL(string: "https://github.com/gpliu3/GPBubble/blob/main/PRIVACY.md")!) {
                        HStack {
                            Text(L("settings.privacy"))
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    // Terms of Service link
                    Link(destination: URL(string: "https://github.com/gpliu3/GPBubble/blob/main/TERMS.md")!) {
                        HStack {
                            Text(L("settings.terms"))
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text(L("settings.about"))
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
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .alert(L("settings.notifications.permission.title"), isPresented: $showingPermissionAlert) {
                Button(L("task.cancel"), role: .cancel) {}
                Button(L("settings.notifications.permission.settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text(L("settings.notifications.permission.message"))
            }
            .task {
                await notificationManager.checkAuthorizationStatus()
            }
        }
    }
}

#Preview {
    SettingsView()
}
