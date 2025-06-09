//
//  SettingsView.swift
//  Yutub
//
//  Created by Pau on 9/6/25.
//

import SwiftUI

// MARK: - Centralized Settings Store
class SettingsStore: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("autoplayEnabled") var autoplayEnabled: Bool = true
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .padding()
            
            // Dark Mode Toggle
            Toggle(isOn: $settings.isDarkMode) {
                Text("Dark Mode")
                    .font(.headline)
            }
            .tint(.red)
            .padding()
            
            // Autoplay Toggle
            Toggle(isOn: $settings.autoplayEnabled) {
                Text("Autoplay")
                    .font(.headline)
            }
            .tint(.red)
            .padding()
            
            Spacer()
        }
        .padding()
    }
}
