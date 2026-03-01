//
//  GPBubbleApp.swift
//  GPBubble
//
//  Created by Gengpu Liu on 18/1/26.
//

import SwiftUI
import SwiftData
import os.log

@main
struct GPBubbleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let modelContainer: ModelContainer?
    private let initError: Error?

    init() {
        let schema = Schema([TaskItem.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.initError = nil
        } catch {
            os_log(.error, "Failed to create ModelContainer: %@", error.localizedDescription)
            self.modelContainer = nil
            self.initError = error
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
            } else {
                DataErrorView(error: initError)
            }
        }
    }
}

/// View shown when data initialization fails
struct DataErrorView: View {
    let error: Error?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Unable to Load Data")
                .font(.title2.weight(.semibold))

            Text("There was a problem loading your tasks. Please try restarting the app.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let error = error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }

            Button("Restart App") {
                // Attempt to restart by exiting (user will relaunch)
                exit(0)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
    }
}
