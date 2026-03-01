//
//  LocalizationManager.swift
//  GPBubble
//

import Foundation
import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            updateBundle()
        }
    }

    private var bundle: Bundle?

    private init() {
        // Load saved language preference, default to system
        self.currentLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "system"
        updateBundle()
    }

    private func updateBundle() {
        if currentLanguage == "system" {
            bundle = nil // Use system default
        } else {
            if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                self.bundle = bundle
            } else {
                self.bundle = nil
            }
        }

        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    func localizedString(_ key: String) -> String {
        if let bundle = bundle {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        } else {
            return NSLocalizedString(key, comment: "")
        }
    }
}

// Convenience function for localization
func L(_ key: String) -> String {
    LocalizationManager.shared.localizedString(key)
}
