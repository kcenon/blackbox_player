/**
 * @file NotificationExtensions.swift
 * @brief NotificationCenter custom notification name extensions
 * @author BlackboxPlayer Development Team
 * @details
 * Defines custom Notification.Name values used throughout the app.
 * Event channels for Pub-Sub pattern to achieve loose coupling between
 * menu actions and UI components.
 *
 * @section pattern Design Pattern
 * **Observer Pattern**
 * - Publisher: Menu buttons → NotificationCenter.post()
 * - Subscriber: View/ViewModel → NotificationCenter.addObserver()
 * - Advantage: Event delivery without direct references (loose coupling)
 *
 * @section usage Usage Example
 * ```swift
 * // Publisher - Menu button
 * Button("Open Folder...") {
 *     NotificationCenter.default.post(name: .openFolderRequested, object: nil)
 * }
 *
 * // Subscriber - ViewModel
 * init() {
 *     NotificationCenter.default.addObserver(
 *         self,
 *         selector: #selector(handleOpenFolder),
 *         name: .openFolderRequested,
 *         object: nil
 *     )
 * }
 * ```
 *
 * @note This pattern acts as a bridge connecting SwiftUI's declarative nature with UIKit's imperative nature
 */

import Foundation

// MARK: - Notification Name Extensions

/**
 * @extension Notification.Name
 * @brief Custom notification name definitions
 *
 * @details
 * Defines Notification.Name constants used globally throughout the BlackboxPlayer app.
 *
 * ## Notification Categories
 *
 * ### 1. File Management
 * - `openFolderRequested`: Open folder selection dialog
 * - `refreshFileListRequested`: Refresh file list
 *
 * ### 2. UI Toggles
 * - `toggleSidebarRequested`: Show/hide sidebar
 * - `toggleMetadataOverlayRequested`: Toggle metadata overlay
 * - `toggleMapOverlayRequested`: Toggle GPS map overlay
 * - `toggleGraphOverlayRequested`: Toggle G-sensor graph overlay
 *
 * ### 3. Playback Control
 * - `playPauseRequested`: Toggle play/pause
 * - `stepForwardRequested`: Step forward one frame
 * - `stepBackwardRequested`: Step backward one frame
 * - `increaseSpeedRequested`: Increase playback speed
 * - `decreaseSpeedRequested`: Decrease playback speed
 * - `normalSpeedRequested`: Return to normal speed (1.0x)
 *
 * ### 4. Help & Info
 * - `showAboutRequested`: Show About window
 * - `showHelpRequested`: Show help
 *
 * @note All notification names follow a consistent naming convention: `<action><Target>Requested`
 */
extension Notification.Name {

    // MARK: - File Management

    /// @var openFolderRequested
    /// @brief Open folder request notification
    /// @details
    /// Posted when the user selects File > Open Folder... menu.
    /// Requests to display a folder selection dialog via NSOpenPanel.
    ///
    /// **Trigger:** Command+O (⌘O) or File menu click
    /// **Subscribers:** FileManagerService, ContentView
    static let openFolderRequested = Notification.Name("openFolderRequested")

    /// @var refreshFileListRequested
    /// @brief File list refresh request notification
    /// @details
    /// Requests to rescan the video file list in the currently open folder.
    ///
    /// **Trigger:** Command+R (⌘R) or File menu click
    /// **Subscribers:** FileManagerService
    static let refreshFileListRequested = Notification.Name("refreshFileListRequested")

    // MARK: - UI Toggles

    /// @var toggleSidebarRequested
    /// @brief Sidebar toggle request notification
    /// @details
    /// Toggles the visibility of NavigationSplitView's sidebar (file list).
    ///
    /// **Trigger:** Option+Command+S (⌥⌘S) or View menu click
    /// **Subscribers:** ContentView
    static let toggleSidebarRequested = Notification.Name("toggleSidebarRequested")

    /// @var toggleMetadataOverlayRequested
    /// @brief Metadata overlay toggle request notification
    /// @details
    /// Toggles metadata information displayed on the video (time, speed, GPS, etc.).
    ///
    /// **Displayed information:**
    /// - Current playback time
    /// - GPS coordinates (latitude/longitude)
    /// - Driving speed (km/h)
    /// - G-sensor values (X, Y, Z axes)
    ///
    /// **Trigger:** Command+1 (⌘1) or View menu click
    /// **Subscribers:** VideoPlayerView
    static let toggleMetadataOverlayRequested = Notification.Name("toggleMetadataOverlayRequested")

    /// @var toggleMapOverlayRequested
    /// @brief GPS map overlay toggle request notification
    /// @details
    /// Toggles the visibility of GPS data-based map overlay.
    ///
    /// **Displayed information:**
    /// - Movement path
    /// - Current location marker
    /// - Direction indicator
    ///
    /// **Trigger:** Command+2 (⌘2) or View menu click
    /// **Subscribers:** VideoPlayerView
    static let toggleMapOverlayRequested = Notification.Name("toggleMapOverlayRequested")

    /// @var toggleGraphOverlayRequested
    /// @brief G-sensor graph overlay toggle request notification
    /// @details
    /// Toggles the visibility of G-sensor (accelerometer) data graph.
    ///
    /// **Displayed information:**
    /// - X, Y, Z-axis acceleration graphs
    /// - Impact event markers
    /// - Real-time synchronization
    ///
    /// **Trigger:** Command+3 (⌘3) or View menu click
    /// **Subscribers:** VideoPlayerView
    static let toggleGraphOverlayRequested = Notification.Name("toggleGraphOverlayRequested")

    // MARK: - Playback Control

    /// @var playPauseRequested
    /// @brief Play/pause toggle request notification
    /// @details
    /// Toggles the video playback state (playing → paused, paused → playing).
    ///
    /// **Trigger:** Space key or Playback menu click
    /// **Subscribers:** VideoPlayerViewModel
    static let playPauseRequested = Notification.Name("playPauseRequested")

    /// @var stepForwardRequested
    /// @brief Step forward one frame request notification
    /// @details
    /// Moves exactly 1 frame (1/30s or 1/60s) forward from the current playback position.
    /// Useful for precise analysis of impact moments.
    ///
    /// **Trigger:** Command+→ (⌘→) or Playback menu click
    /// **Subscribers:** VideoPlayerViewModel
    static let stepForwardRequested = Notification.Name("stepForwardRequested")

    /// @var stepBackwardRequested
    /// @brief Step backward one frame request notification
    /// @details
    /// Moves exactly 1 frame backward from the current playback position.
    ///
    /// **Trigger:** Command+← (⌘←) or Playback menu click
    /// **Subscribers:** VideoPlayerViewModel
    static let stepBackwardRequested = Notification.Name("stepBackwardRequested")

    /// @var increaseSpeedRequested
    /// @brief Increase playback speed request notification
    /// @details
    /// Increases playback speed by one step.
    ///
    /// **Speed steps:** 0.25x → 0.5x → 1.0x → 1.5x → 2.0x → 4.0x
    ///
    /// **Trigger:** Command+] (⌘]) or Playback menu click
    /// **Subscribers:** VideoPlayerViewModel
    static let increaseSpeedRequested = Notification.Name("increaseSpeedRequested")

    /// @var decreaseSpeedRequested
    /// @brief Decrease playback speed request notification
    /// @details
    /// Decreases playback speed by one step.
    ///
    /// **Speed steps:** 4.0x → 2.0x → 1.5x → 1.0x → 0.5x → 0.25x
    ///
    /// **Trigger:** Command+[ (⌘[) or Playback menu click
    /// **Subscribers:** VideoPlayerViewModel
    static let decreaseSpeedRequested = Notification.Name("decreaseSpeedRequested")

    /// @var normalSpeedRequested
    /// @brief Normal speed return request notification
    /// @details
    /// Immediately returns playback speed to 1.0x (normal speed).
    ///
    /// **Trigger:** Command+0 (⌘0) or Playback menu click
    /// **Subscribers:** VideoPlayerViewModel
    static let normalSpeedRequested = Notification.Name("normalSpeedRequested")

    // MARK: - Help & Info

    /// @var showAboutRequested
    /// @brief Show About window request notification
    /// @details
    /// Opens the About window displaying app information, version, copyright, and license information.
    ///
    /// **Trigger:** BlackboxPlayer > About BlackboxPlayer menu click
    /// **Subscribers:** ContentView
    static let showAboutRequested = Notification.Name("showAboutRequested")

    /// @var showHelpRequested
    /// @brief Show help request notification
    /// @details
    /// Displays app usage help (HelpView or external documentation link).
    ///
    /// **Trigger:** Command+? (⌘?) or Help menu click
    /// **Subscribers:** ContentView
    static let showHelpRequested = Notification.Name("showHelpRequested")
}
