/**
 * @file BlackboxPlayerApp.swift
 * @brief Entry point for the macOS blackbox video player application
 * @author BlackboxPlayer Team
 * @details
 * This file defines the entry point and top-level structure of the BlackboxPlayer app.
 * It adopts the SwiftUI App protocol to manage the app's lifecycle and configure
 * the main window and menu system.
 *
 * @section app_structure App Structure
 * - Program entry point specified with @main annotation
 * - Main window configuration via WindowGroup
 * - Menu customization via Commands modifier
 * - Keyboard shortcut definitions
 *
 * @section ui_components UI Components
 * - Title bar hidden with hiddenTitleBar style
 * - File, View, Playback, Help menu customization
 * - Multi-window support (Cmd+N)
 *
 * @section keyboard_shortcuts Main Keyboard Shortcuts
 * - ⌘O: Open folder
 * - ⌘R: Refresh file list
 * - ⌘1/2/3: Toggle overlays
 * - Space: Play/Pause
 * - ⌘←/→: Frame-by-frame navigation
 * - ⌘[/]: Adjust playback speed
 *
 * @note Defines app structure declaratively by adopting SwiftUI's App protocol.
 * @note Modern approach that consolidates UIKit's AppDelegate/SceneDelegate structure into a single file.
 *
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║                        BlackboxPlayer App Entry Point                        ║
 * ║                   SwiftUI App Entry Point and Lifecycle Management           ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝

 📚 Purpose of This File
 ════════════════════════════════════════════════════════════════════════════════
 This file defines the entry point and top-level structure of the BlackboxPlayer app.

 It adopts SwiftUI's App protocol to manage the app's lifecycle and configure
 the main window and menu system.

 📌 Main Responsibilities:
 1) Define app entry point (@main annotation)
 2) Configure main window (WindowGroup)
 3) Customize menus (Commands)
 4) Define keyboard shortcuts


 🚀 What is the @main Annotation?
 ════════════════════════════════════════════════════════════════════════════════
 Swift's @main annotation marks the program's entry point.

 📌 Basic Concept:
 Every executable program needs a starting point.
 Like C/C++'s main() function, Swift needs to specify where to start.

 📌 Role of @main:
 • Designates this type as the app's starting point
 • System creates an instance of this type when running the app
 • Can only be used on types that adopt the App protocol
 • Only one can exist in the entire project

 📌 Comparison with UIKit:
 UIKit Era (Complex):
 - AppDelegate.swift (app lifecycle)
 - SceneDelegate.swift (scene lifecycle)
 - main.swift or @UIApplicationMain
 → Structure distributed across 3 files

 SwiftUI Era (Simple):
 - Consolidated into one @main annotation
 - Declarative approach
 → Complete in 1 file


 📱 What is the App Protocol?
 ════════════════════════════════════════════════════════════════════════════════
 SwiftUI's App protocol defines the structure and behavior of the app.

 📌 Required Implementation:
 protocol App {
 associatedtype Body: Scene
 var body: Self.Body { get }
 }

 • Must implement body property
 • body returns Scene type (not View!)
 • Scene represents the UI hierarchy of the app

 📌 App vs View:
 App (Top Level):
 - Defines overall app structure
 - Container for Scenes
 - Manages lifecycle

 Scene (Middle):
 - WindowGroup, DocumentGroup, etc.
 - Platform-specific window/screen units

 View (Bottom):
 - UI components
 - Button, Text, ContentView, etc.


 🪟 What are Scene and WindowGroup?
 ════════════════════════════════════════════════════════════════════════════════
 Scene represents an instance of the app's user interface.

 📌 Types of Scenes:
 1) WindowGroup
 - Manages one or more windows
 - macOS: Multiple window instances possible (new window with Cmd+N)
 - iOS/iPadOS: Multi-window support (iPadOS)

 2) DocumentGroup
 - Document-based apps (e.g., Pages, Keynote)
 - File system integration

 3) Settings (macOS only)
 - Dedicated settings window

 📌 WindowGroup Characteristics:
 • Displays the same View hierarchy in multiple windows
 • macOS: Create new windows with Cmd+N
 • Each window can maintain independent state
 • Automatically adds Window menu items

 📌 This Project's WindowGroup:
 WindowGroup { ContentView() }
 → Creates a window with ContentView as the root
 → Supports multiple windows so users can view multiple blackbox videos simultaneously


 🎨 What is the windowStyle Modifier?
 ════════════════════════════════════════════════════════════════════════════════
 windowStyle is a modifier that customizes the window's appearance.

 📌 .hiddenTitleBar:
 • Hides the title bar (title display bar)
 • Provides more content area
 • Modern and minimal design
 • Retains close/minimize/maximize buttons

 📌 Other windowStyle Options:
 • .automatic: Default style (shows title bar)
 • .titleBar: Explicitly shows title bar
 • .hiddenTitleBar: Hides title bar

 📌 Why use hiddenTitleBar?
 The blackbox video player focuses on video content, so hiding the title bar
 maximizes screen space usage.
 (Similar UX to video players like YouTube, Netflix)


 ⌨️ What is the Commands System?
 ════════════════════════════════════════════════════════════════════════════════
 Commands is a system for customizing menu items in the macOS menu bar.

 📌 Basic Concept:
 SwiftUI automatically generates default menus, but Commands allows you to
 add, modify, or replace menus.

 📌 Types of Commands:

 1) CommandGroup(replacing:)
 - Completely replaces existing menu groups
 - Can replace standard groups like .newItem, .appInfo

 2) CommandGroup(after:) / CommandGroup(before:)
 - Adds new items before/after existing menu groups
 - Specifies reference points like .sidebar, .toolbar

 3) CommandMenu("Name")
 - Creates a completely new menu
 - Adds a new tab to the menu bar

 📌 Standard CommandGroupPlacement:
 • .newItem: File > New
 • .saveItem: File > Save
 • .sidebar: View > Sidebar related
 • .toolbar: View > Toolbar related
 • .appInfo: App > About


 🎮 This Project's Menu Structure
 ════════════════════════════════════════════════════════════════════════════════

 1. File Menu (CommandGroup replacing .newItem)
 - Open Folder... (⌘O): Open blackbox video folder
 - Refresh File List (⌘R): Refresh file list

 2. View Menu (CommandGroup after .sidebar)
 - Toggle Sidebar (⌥⌘S): Show/hide sidebar
 - Toggle Metadata Overlay (⌘1): Metadata overlay
 - Toggle Map Overlay (⌘2): GPS map overlay
 - Toggle Graph Overlay (⌘3): G-sensor graph overlay

 3. Playback Menu (New CommandMenu)
 - Play/Pause (Space): Play/pause
 - Step Forward (⌘→): Frame-by-frame forward
 - Step Backward (⌘←): Frame-by-frame backward
 - Increase Speed (⌘]): Increase playback speed
 - Decrease Speed (⌘[): Decrease playback speed
 - Normal Speed (⌘0): Return to normal speed

 4. Help Menu (CommandGroup replacing .appInfo)
 - About BlackboxPlayer: Display app info
 - BlackboxPlayer Help (⌘?): Display help


 ⌨️ What is the keyboardShortcut Modifier?
 ════════════════════════════════════════════════════════════════════════════════
 A modifier that assigns keyboard shortcuts to Buttons or menu items.

 📌 Usage:
 .keyboardShortcut(key, modifiers: [modifiers])

 • key: KeyEquivalent type (characters, arrows, etc.)
 • modifiers: EventModifiers (command, option, shift, control)

 📌 KeyEquivalent Types:
 1) Characters: "o", "r", "s", "0", "1", "2", "3"
 2) Symbols: "[", "]", "?", "/"
 3) Special Keys: .space, .escape, .return, .delete
 4) Arrows: .leftArrow, .rightArrow, .upArrow, .downArrow

 📌 EventModifiers Combinations:
 • .command (⌘): Command key
 • .option (⌥): Option(Alt) key
 • .shift (⇧): Shift key
 • .control (⌃): Control key
 • Can be combined in arrays: [.command, .option]

 📌 This Project's Shortcut Philosophy:
 • ⌘O: Open (standard macOS convention)
 • ⌘R: Refresh (standard macOS convention)
 • ⌘1/2/3: Toggle overlays (quick switching with number keys)
 • Space: Play/pause (video player standard)
 • ⌘←/→: Frame navigation (timeline exploration)
 • ⌘[/]: Speed adjustment (increase/decrease with brackets)


 💡 About TODO Items
 ════════════════════════════════════════════════════════════════════════════════
 Currently all button actions have TODO comments.

 📌 Meaning of TODO:
 This file only defines the app's structure.
 Actual feature implementation is handled in separate ViewModels or Services.

 📌 Future Implementation Direction:
 1) Create ViewModel or AppState
 @StateObject var appState = AppState()

 2) Pass as environment object
 .environmentObject(appState)

 3) Call in button actions
 Button("Open Folder...") {
 appState.openFolderPicker()
 }

 📌 SwiftUI Architecture Pattern:
 App (Structure definition)
 → Scene (Window management)
 → View (UI presentation)
 → ViewModel (Business logic)
 → Service (Data/features)

 This file only performs the top-level "structure definition" role,
 while detailed features are implemented in lower layers.


 ═══════════════════════════════════════════════════════════════════════════════
 */

import SwiftUI

// MARK: - App Entry Point

/**
 * @class BlackboxPlayerApp
 * @brief Main entry point structure for the BlackboxPlayer app
 * @details
 * Adopts SwiftUI's App protocol to manage the app's lifecycle and main UI.
 *
 * @note @main annotation
 * - Designates this type as the program's starting point
 * - System creates a BlackboxPlayerApp instance
 * - Evaluates the body property to configure the Scene
 * - Displays the main window with WindowGroup defined in the Scene
 * - Only one @main can exist in the entire project
 *
 * @par Execution Order:
 * 1. System creates a BlackboxPlayerApp instance
 * 2. Evaluates the body property
 * 3. Displays the main window with WindowGroup
 *
 * 📌 Explanation of @main for Beginners
 * ─────────────────────────────────────────────────────────────────
 * The @main annotation designates this type as the program's starting point.
 *
 * When the app runs:
 * 1) System creates an instance of BlackboxPlayerApp
 * 2) Evaluates the body property to configure the Scene
 * 3) Displays the main window with WindowGroup defined in the Scene
 *
 * Only one @main should exist in the entire project.
 */
@main
struct BlackboxPlayerApp: App {

    // MARK: Scene Configuration

    /**
     * @var body
     * @brief Property that defines the app's Scene configuration
     * @return Scene composed of WindowGroup and Commands
     * @details
     * This is the body property required by the App protocol.
     *
     * @par Scene Structure:
     * - WindowGroup: Defines the main window group
     *   - Uses ContentView() as the root view
     *   - Can create multiple window instances on macOS (Cmd+N)
     * - .windowStyle(.hiddenTitleBar): Hides the title bar
     *   - Maximizes screen space to focus on video content
     *   - Retains close/minimize/maximize buttons
     * - .commands: Menu customization
     *   - Defines File, View, Playback, Help menus
     *   - Assigns keyboard shortcuts
     *
     * @note body returns "some Scene" type
     * @note some is Swift 5.1+ Opaque Type
     * @note Scene is a protocol representing the app's UI hierarchy
     */
    /// App's Scene configuration
    ///
    /// 📌 Explanation of body for Beginners
    /// ─────────────────────────────────────────────────────────────────
    /// This is the body property required by the App protocol.
    ///
    /// body returns "some Scene" type:
    /// • some: Opaque Type (Swift 5.1+)
    /// • Scene: Protocol representing the app's UI hierarchy
    ///
    /// WindowGroup, DocumentGroup, etc. adopt Scene.
    ///
    ///
    /// 🏗️ Scene Structure Explanation
    /// ─────────────────────────────────────────────────────────────────
    /// 1) WindowGroup: Defines the main window group
    ///    - Uses ContentView() as the root view
    ///    - Can create multiple window instances on macOS (Cmd+N)
    ///
    /// 2) .windowStyle(.hiddenTitleBar): Hides the title bar
    ///    - Maximizes screen space to focus on video content
    ///    - Retains close/minimize/maximize buttons
    ///
    /// 3) .commands: Menu customization
    ///    - Adds/modifies menu items in the macOS menu bar
    ///    - Defines File, View, Playback, Help menus
    ///
    var body: some Scene {
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // WindowGroup: Main window definition
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // 📌 What is WindowGroup?
        //    One of SwiftUI's Scene types that manages one or more windows.
        //
        // 📌 How it works:
        //    When a user selects File > New Window (Cmd+N) on macOS,
        //    WindowGroup creates a window with a new instance of ContentView().
        //
        // 📌 ContentView():
        //    The root view that defines the app's main UI.
        //    This view becomes the starting point of the entire UI hierarchy.
        //
        // 📌 Why use trailing closure syntax?
        //    WindowGroup's constructor accepts @ViewBuilder:
        //    WindowGroup(@ViewBuilder content: () -> Content)
        //
        //    Views can be declaratively composed inside the closure.
        //
        WindowGroup {
            ContentView()
        }
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Window Style: Hide title bar
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // 📌 Effect of .hiddenTitleBar:
        //    • Removes the title bar at the top of the window
        //    • Content area occupies the entire window
        //    • Traffic light buttons (close/minimize/maximize) are retained
        //
        // 📌 Reason for use:
        //    The blackbox video player focuses on video as the main content,
        //    so the title bar area is allocated to content to enhance immersion
        //
        // 📌 Alternatives:
        //    .windowStyle(.titleBar) → Shows title bar (default)
        //    .windowStyle(.automatic) → System default style
        //
        .windowStyle(.hiddenTitleBar)

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Commands: Menu customization
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // 📌 What is the .commands modifier?
        //    A modifier that customizes menu items in the macOS menu bar.
        //
        // 📌 @CommandsBuilder:
        //    The .commands { } closure accepts @CommandsBuilder.
        //    Multiple CommandGroups and CommandMenus can be declaratively composed.
        //
        // 📌 Menu composition methods:
        //    1) CommandGroup(replacing:) - Replace existing menus
        //    2) CommandGroup(after/before:) - Add items to existing menus
        //    3) CommandMenu("Name") - Create new menus
        //
        .commands {

            // ═══════════════════════════════════════════════════════════════
            // File menu customization
            // ═══════════════════════════════════════════════════════════════
            //
            // 📌 CommandGroup(replacing: .newItem):
            //    Completely replaces the default "File > New" menu group.
            //
            // 📌 Why replace it?
            //    The blackbox player has no "new document" concept,
            //    so instead provides "open folder" and "refresh" functionality.
            //
            // 📌 What is .newItem?
            //    CommandGroupPlacement.newItem is a standard macOS menu position.
            //    Usually located in the first group of the File menu.
            //
            CommandGroup(replacing: .newItem) {

                // ───────────────────────────────────────────────────────────
                // Open Folder button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Open Folder..."):
                //    A button that will be displayed as a menu item.
                //    The "..." notation is a macOS convention meaning "additional dialog will open".
                //
                // 📌 TODO: Open folder picker
                //    Will implement folder selection dialog using NSOpenPanel in the future
                //
                // 📌 Implementation example (future):
                //    let panel = NSOpenPanel()
                //    panel.canChooseFiles = false
                //    panel.canChooseDirectories = true
                //    panel.begin { response in ... }
                //
                Button("Open Folder...") {
                    NotificationCenter.default.post(name: .openFolderRequested, object: nil)
                }
                // 📌 .keyboardShortcut("o", modifiers: .command):
                //    Assigns Command+O (⌘O) shortcut
                //
                //    "o" is a KeyEquivalent type representing the character "o".
                //    .command is EventModifiers meaning the Command(⌘) key.
                //
                //    ⌘O is the standard macOS "Open" shortcut.
                //    (Used in all apps like Finder, Safari, TextEdit)
                //
                .keyboardShortcut("o", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Divider: Menu separator
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Divider():
                //    Adds a visual separator line between menu items.
                //    Groups related items to improve readability.
                //
                // 📌 macOS menu design guidelines:
                //    It's recommended to separate semantically different functions with a Divider.
                //    (Open and Refresh are different operations, so use a separator)
                //
                Divider()

                // ───────────────────────────────────────────────────────────
                // Refresh File List button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Refresh File List"):
                //    Refreshes the file list of the currently open folder.
                //
                // 📌 TODO: Refresh files
                //    Will call FileSystemService to rescan the file list
                //
                // 📌 Implementation example (future):
                //    await fileSystemService.refreshFiles()
                //    await videoLibrary.reload()
                //
                Button("Refresh File List") {
                    NotificationCenter.default.post(name: .refreshFileListRequested, object: nil)
                }
                // 📌 .keyboardShortcut("r", modifiers: .command):
                //    Assigns Command+R (⌘R) shortcut
                //
                //    ⌘R is the standard macOS shortcut for "Refresh/Reload".
                //    (Used in Safari refresh, Xcode build, etc.)
                //
                .keyboardShortcut("r", modifiers: .command)
            }

            // ═══════════════════════════════════════════════════════════════
            // Add View menu items
            // ═══════════════════════════════════════════════════════════════
            //
            // 📌 CommandGroup(after: .sidebar):
            //    Adds new items after the default "View > Sidebar" group.
            //
            // 📌 What is .sidebar?
            //    CommandGroupPlacement.sidebar is the standard position for
            //    sidebar-related items in the View menu.
            //
            // 📌 Why use after?
            //    Keeps the existing "Hide/Show Sidebar" items while
            //    additionally providing view options specific to the blackbox player.
            //
            CommandGroup(after: .sidebar) {

                // ───────────────────────────────────────────────────────────
                // Toggle Sidebar button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Toggle Sidebar"):
                //    Toggles the display/hide of the sidebar (file list).
                //
                // 📌 TODO: Toggle sidebar
                //    Will toggle columnVisibility of NavigationSplitView
                //
                // 📌 Implementation example (future):
                //    @State var sidebarVisibility: NavigationSplitViewVisibility
                //    sidebarVisibility = sidebarVisibility == .all ? .detailOnly : .all
                //
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebarRequested, object: nil)
                }
                // 📌 .keyboardShortcut("s", modifiers: [.command, .option]):
                //    Assigns Option+Command+S (⌥⌘S) shortcut
                //
                //    Multiple modifiers can be combined in the modifiers array.
                //    [.command, .option] means pressing both keys simultaneously.
                //
                //    ⌥⌘S is used for sidebar toggle in many macOS apps.
                //    (Xcode, Finder, etc.)
                //
                .keyboardShortcut("s", modifiers: [.command, .option])

                Divider()

                // ───────────────────────────────────────────────────────────
                // Toggle Metadata Overlay button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Toggle Metadata Overlay"):
                //    Shows/hides the metadata overlay on top of the video.
                //
                // 📌 What is the metadata overlay?
                //    Displays the following information on screen during video playback:
                //    - Current time
                //    - GPS coordinates
                //    - Speed
                //    - G-sensor values
                //
                // 📌 TODO: Toggle metadata
                //    Will toggle @State var showMetadata: Bool variable
                //
                Button("Toggle Metadata Overlay") {
                    NotificationCenter.default.post(name: .toggleMetadataOverlayRequested, object: nil)
                }
                // 📌 .keyboardShortcut("1", modifiers: .command):
                //    Assigns Command+1 (⌘1) shortcut
                //
                //    Number keys (1, 2, 3) are used to quickly switch between different overlays.
                //    The number order represents priority (1=metadata, 2=map, 3=graph)
                //
                .keyboardShortcut("1", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Toggle Map Overlay button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Toggle Map Overlay"):
                //    Shows/hides the map overlay based on GPS data.
                //
                // 📌 What is the map overlay?
                //    Displays current location on a map during video playback:
                //    - Travel path
                //    - Current location marker
                //    - Scale and direction
                //
                // 📌 TODO: Toggle map
                //    Will implement functionality to show/hide MapKit view
                //
                Button("Toggle Map Overlay") {
                    NotificationCenter.default.post(name: .toggleMapOverlayRequested, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Toggle Graph Overlay button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Toggle Graph Overlay"):
                //    Shows/hides G-sensor data as a graph.
                //
                // 📌 What is the graph overlay?
                //    Visualizes G-sensor (acceleration) data over time:
                //    - X, Y, Z axis acceleration graphs
                //    - Impact event display
                //    - Real-time synchronization
                //
                // 📌 TODO: Toggle graph
                //    Will show/hide graph view using Charts framework
                //
                Button("Toggle Graph Overlay") {
                    NotificationCenter.default.post(name: .toggleGraphOverlayRequested, object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)
            }

            // ═══════════════════════════════════════════════════════════════
            // Create Playback menu (new menu)
            // ═══════════════════════════════════════════════════════════════
            //
            // 📌 CommandMenu("Playback"):
            //    Adds a new menu named "Playback" to the menu bar.
            //
            // 📌 Position:
            //    Located right before the Help menu in the menu bar.
            //    (App, File, Edit, View, Playback, Window, Help order)
            //
            // 📌 Why create a new menu?
            //    Video playback functionality is a core feature of the blackbox player,
            //    so it's separated into its own menu for better accessibility.
            //
            CommandMenu("Playback") {

                // ───────────────────────────────────────────────────────────
                // Play/Pause button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Play/Pause"):
                //    Toggles video playback/pause.
                //
                // 📌 TODO: Play/pause
                //    Will call VideoPlayerService's togglePlayPause() method
                //
                // 📌 Implementation example (future):
                //    if videoPlayer.isPlaying {
                //        videoPlayer.pause()
                //    } else {
                //        videoPlayer.play()
                //    }
                //
                Button("Play/Pause") {
                    NotificationCenter.default.post(name: .playPauseRequested, object: nil)
                }
                // 📌 .keyboardShortcut(.space):
                //    Assigns Space key shortcut
                //
                //    .space is shorthand for KeyEquivalent.space.
                //    Works with just the Space key without modifiers.
                //
                //    Space is the standard play/pause shortcut for all video players.
                //    (YouTube, QuickTime, VLC, etc.)
                //
                .keyboardShortcut(.space)

                Divider()

                // ───────────────────────────────────────────────────────────
                // Step Forward button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Step Forward"):
                //    Moves the video forward one frame at a time.
                //
                // 📌 What is frame-by-frame movement?
                //    Precisely navigates the video in 1/30 or 1/60 second units.
                //    Useful for accurately analyzing impact moments.
                //
                // 📌 TODO: Step forward
                //    Will move exactly 1 frame forward from current playback position
                //
                Button("Step Forward") {
                    NotificationCenter.default.post(name: .stepForwardRequested, object: nil)
                }
                // 📌 .keyboardShortcut(.rightArrow, modifiers: .command):
                //    Assigns Command+→ (⌘→) shortcut
                //
                //    .rightArrow is KeyEquivalent.rightArrow.
                //    Press right arrow key together with Command.
                //
                //    Arrow key navigation is standard for video editing tools.
                //    (Final Cut Pro, Adobe Premiere, etc.)
                //
                .keyboardShortcut(.rightArrow, modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Step Backward button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Step Backward"):
                //    Moves the video backward one frame at a time.
                //
                // 📌 TODO: Step backward
                //    Will move exactly 1 frame backward from current playback position
                //
                Button("Step Backward") {
                    NotificationCenter.default.post(name: .stepBackwardRequested, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                // ───────────────────────────────────────────────────────────
                // Increase Speed button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Increase Speed"):
                //    Increases playback speed (e.g., 1x → 1.5x → 2x → 4x).
                //
                // 📌 Purpose of speed control:
                //    Used to quickly review long driving videos or
                //    slowly analyze specific sections.
                //
                // 📌 TODO: Increase speed
                //    Will increase videoPlayer.rate (0.5x ~ 4x range)
                //
                Button("Increase Speed") {
                    NotificationCenter.default.post(name: .increaseSpeedRequested, object: nil)
                }
                // 📌 .keyboardShortcut("]", modifiers: .command):
                //    Assigns Command+] (⌘]) shortcut
                //
                //    "]" (closing bracket) represents "increase".
                //    Pairs intuitively with "[" (opening bracket).
                //
                //    Many video apps use brackets for speed control.
                //    (VLC, IINA, etc.)
                //
                .keyboardShortcut("]", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Decrease Speed button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Decrease Speed"):
                //    Decreases playback speed (e.g., 2x → 1.5x → 1x → 0.5x).
                //
                // 📌 TODO: Decrease speed
                //    Will decrease videoPlayer.rate (0.5x ~ 4x range)
                //
                Button("Decrease Speed") {
                    NotificationCenter.default.post(name: .decreaseSpeedRequested, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                // ───────────────────────────────────────────────────────────
                // Normal Speed button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("Normal Speed"):
                //    Returns playback speed to normal (1.0x).
                //
                // 📌 TODO: Normal speed
                //    Will set videoPlayer.rate = 1.0
                //
                Button("Normal Speed") {
                    NotificationCenter.default.post(name: .normalSpeedRequested, object: nil)
                }
                // 📌 .keyboardShortcut("0", modifiers: .command):
                //    Assigns Command+0 (⌘0) shortcut
                //
                //    "0" means "restore to default value".
                //    Similar to how ⌘0 means "actual size" in Xcode.
                //
                .keyboardShortcut("0", modifiers: .command)
            }

            // ═══════════════════════════════════════════════════════════════
            // Help menu customization
            // ═══════════════════════════════════════════════════════════════
            //
            // 📌 CommandGroup(replacing: .appInfo):
            //    Replaces the default "About App" menu item.
            //
            // 📌 What is .appInfo?
            //    CommandGroupPlacement.appInfo is the standard position for displaying app info.
            //    Usually the first item in the App menu.
            //
            // 📌 Why replace it?
            //    Defines button actions directly to show a custom About window
            //    instead of the default About window.
            //
            CommandGroup(replacing: .appInfo) {

                // ───────────────────────────────────────────────────────────
                // About BlackboxPlayer button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("About BlackboxPlayer"):
                //    Opens a window displaying app information (version, copyright, license, etc.).
                //
                // 📌 TODO: Show about window
                //    Will display custom About window (Sheet or Window)
                //
                // 📌 Implementation example (future):
                //    @State var showAbout = false
                //    .sheet(isPresented: $showAbout) {
                //        AboutView()
                //    }
                //
                Button("About BlackboxPlayer") {
                    NotificationCenter.default.post(name: .showAboutRequested, object: nil)
                }

                Divider()

                // ───────────────────────────────────────────────────────────
                // BlackboxPlayer Help button
                // ───────────────────────────────────────────────────────────
                //
                // 📌 Button("BlackboxPlayer Help"):
                //    Displays help on how to use the app.
                //
                // 📌 TODO: Show help
                //    Will open help view or external documentation link
                //
                // 📌 Implementation example (future):
                //    NSWorkspace.shared.open(helpURL)
                //    or display custom HelpView()
                //
                Button("BlackboxPlayer Help") {
                    NotificationCenter.default.post(name: .showHelpRequested, object: nil)
                }
                // 📌 .keyboardShortcut("?", modifiers: .command):
                //    Assigns Command+? (⌘?) shortcut
                //
                //    Same as Shift+Command+/ (? is Shift+/ key)
                //    ⌘? is the standard macOS "Help" shortcut.
                //
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
