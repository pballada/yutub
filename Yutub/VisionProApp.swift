//
//  VisionProApp.swift
//  Yutub
//
//  Created by Pau on 9/6/25.
//

import SwiftUI

// MARK: - App Entry
@main
struct VisionProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SettingsStore())
        }
    }
}

