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
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    // TODO: Open folder picker
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Refresh File List") {
                    // TODO: Refresh files
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            // View menu
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    // TODO: Toggle sidebar
                }
                .keyboardShortcut("s", modifiers: [.command, .option])

                Divider()

                Button("Toggle Metadata Overlay") {
                    // TODO: Toggle metadata
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Toggle Map Overlay") {
                    // TODO: Toggle map
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Toggle Graph Overlay") {
                    // TODO: Toggle graph
                }
                .keyboardShortcut("3", modifiers: .command)
            }

            // Playback menu
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    // TODO: Play/pause
                }
                .keyboardShortcut(.space)

                Divider()

                Button("Step Forward") {
                    // TODO: Step forward
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("Step Backward") {
                    // TODO: Step backward
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("Increase Speed") {
                    // TODO: Increase speed
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Decrease Speed") {
                    // TODO: Decrease speed
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Normal Speed") {
                    // TODO: Normal speed
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            // Help menu
            CommandGroup(replacing: .appInfo) {
                Button("About BlackboxPlayer") {
                    // TODO: Show about window
                }

                Divider()

                Button("BlackboxPlayer Help") {
                    // TODO: Show help
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
