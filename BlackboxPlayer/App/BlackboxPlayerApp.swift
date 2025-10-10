//
//  BlackboxPlayerApp.swift
//  BlackboxPlayer
//
//  macOS Dashcam Video Player Application
//

import SwiftUI

@main
struct BlackboxPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BlackboxPlayer") {
                    // TODO: Show about window
                }
            }
        }
    }
}
