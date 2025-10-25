/// @file MultiChannelPlayerView.swift
/// @brief Multi-channel synchronized video player View
/// @author BlackboxPlayer Development Team
/// @details A player that simultaneously plays 4 cameras (Front, Rear, Left, Right).
///          Provides Metal rendering, GPS/G-Sensor overlay, fullscreen mode, and screenshot capture features.
///
/// ## Key Features
/// - **Multi-channel synchronized playback**: Simultaneous playback of 4 cameras (Front, Rear, Left, Right)
/// - **Metal rendering**: High-performance rendering with MTKView and MultiChannelRenderer
/// - **Layout modes**: Grid (2x2), Focus (one large), Horizontal (side-by-side)
/// - **Video transformations**: Real-time adjustment of brightness, zoom, horizontal/vertical flip
/// - **GPS/G-Sensor overlay**: Real-time display of map and acceleration graph
/// - **Fullscreen mode**: Auto-hide controls (after 3 seconds)
/// - **Screenshot capture**: Save current frame as PNG
///
/// ## Layout Structure
/// ```
/// ┌────────────────────────────────────────────────┐
/// │ [Grid][Focus][Horizontal]  [Transform]  [F][R] │ ← Top bar (layout + channel selection)
/// ├────────────────────────────────────────────────┤
/// │                                                │
/// │   ┌──────────┬──────────┐                     │
/// │   │  Front   │   Rear   │  (Grid mode)        │
/// │   ├──────────┼──────────┤                     │ ← Metal rendering area
/// │   │  Left    │  Right   │                     │
/// │   └──────────┴──────────┘                     │
/// │                                                │
/// │   GPS map (bottom left)  G-Sensor graph (right)│ ← Overlays
/// ├────────────────────────────────────────────────┤
/// │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ ← Timeline
/// │ 00:30 / 01:30                                  │
/// │ [▶] [⏪10] [⏩10]  [1.0x]  [📷] [⛶]           │ ← Playback controls
/// └────────────────────────────────────────────────┘
/// ```
///
/// ## Core Concepts
/// ### 1. Multi-channel Synchronized Playback
/// Plays 4 independent video files simultaneously, with SyncController handling synchronization.
///
/// **Synchronization principle:**
/// ```
/// SyncController
///     ├─ FrontDecoder (decoder1)
///     ├─ RearDecoder (decoder2)
///     ├─ LeftDecoder (decoder3)
///     └─ RightDecoder (decoder4)
///
/// During playback:
/// 1. Call SyncController.play()
///      ↓
/// 2. All decoders decode frames at the same time (currentTime)
///      ↓
/// 3. getSynchronizedFrames() → [FrontFrame, RearFrame, LeftFrame, RightFrame]
///      ↓
/// 4. MultiChannelRenderer renders all 4 frames simultaneously
///      ↓
/// 5. All 4 videos are displayed synchronized on screen
/// ```
///
/// ### 2. Metal Rendering
/// Metal is Apple's high-performance graphics API for efficiently rendering multiple videos.
///
/// **Rendering pipeline:**
/// ```
/// MTKView (60 FPS rendering)
///     ↓
/// draw(in view:) called (60Hz)
///     ↓
/// getSynchronizedFrames() → [VideoFrame, VideoFrame, ...]
///     ↓
/// MultiChannelRenderer.render() → Execute Metal Shader
///     ↓
/// GPU renders 4 videos as textures
///     ↓
/// Display on screen (vsync synchronized)
/// ```
///
/// ### 3. Layout Modes
/// - **Grid (2x2)**: Arrange 4 videos in 2x2 grid
/// - **Focus**: Display only 1 selected video large
/// - **Horizontal**: Arrange 4 videos horizontally
///
/// **Layout transitions:**
/// ```swift
/// layoutMode = .grid        // 2x2 grid
/// layoutMode = .focus       // One large
/// layoutMode = .horizontal  // Horizontal arrangement
/// ```
///
/// ### 4. Auto-hide Controls
/// In fullscreen mode, controls automatically disappear after 3 seconds of no mouse movement.
///
/// **Operation flow:**
/// ```
/// Enter fullscreen
///      ↓
/// Detect mouse movement → call resetControlsTimer()
///      ↓
/// Start timer (3 seconds)
///      ↓ No mouse movement for 3 seconds
/// showControls = false → Hide controls
///      ↓ Mouse moves again
/// showControls = true → Show controls
/// ```
///
/// ## Usage Example
/// ```swift
/// // 1. Create player by passing VideoFile
/// let videoFile = VideoFile(...)
/// MultiChannelPlayerView(videoFile: videoFile)
///
/// // 2. Player automatically:
/// //    - Loads 4 channels from videoFile.channels
/// //    - Plays synchronized with SyncController
/// //    - Renders with Metal
/// //    - Displays GPS/G-Sensor overlay
///
/// // 3. User interactions:
/// //    - [Grid] button → 2x2 layout
/// //    - [F] button → Show Front channel large
/// //    - [▶] button → Play/Pause
/// //    - [1.0x] menu → Adjust playback speed
/// //    - [📷] button → Capture screenshot
/// //    - [⛶] button → Toggle fullscreen
/// ```
///
/// ## Real-world Scenarios
/// **Scenario 1: Playing blackbox video**
/// ```
/// 1. User selects video file from FileListView
///      ↓
/// 2. MultiChannelPlayerView(videoFile: file) created
///      ↓
/// 3. loadVideoFile() → syncController.loadVideoFile(videoFile)
///      ↓
/// 4. Initialize 4 channel decoders (Front, Rear, Left, Right)
///      ↓
/// 5. Start Metal rendering in MetalVideoView
///      ↓
/// 6. Display GPS map + G-Sensor graph overlay
///      ↓
/// 7. User clicks Play button → Synchronized playback of 4 videos
/// ```
///
/// **Scenario 2: Changing layout**
/// ```
/// 1. Initial state: Grid mode (2x2)
///      ┌──────┬──────┐
///      │Front │Rear  │
///      ├──────┼──────┤
///      │Left  │Right │
///      └──────┴──────┘
///
/// 2. Click [F] button → Switch to Focus mode
///      ┌────────────────┐
///      │                │
///      │     Front      │
///      │                │
///      └────────────────┘
///
/// 3. Click [Horizontal] button → Horizontal arrangement
///      ┌────┬────┬────┬────┐
///      │Fron│Rear│Left│Righ│
///      └────┴────┴────┴────┘
/// ```
///
/// **Scenario 3: Video transformation (brightness adjustment)**
/// ```
/// 1. Click [Transform] button → Show transformation controls
///      ↓
/// 2. Adjust Brightness slider to 0.5
///      ↓
/// 3. transformationService.setBrightness(0.5)
///      ↓
/// 4. Apply brightness increase effect in Metal Shader
///      ↓
/// 5. All 4 videos become brighter (real-time)
/// ```
//
//  MultiChannelPlayerView.swift
//  BlackboxPlayer
//
//  Multi-channel synchronized video player view
//

import SwiftUI
import MetalKit

/// @struct MultiChannelPlayerView
/// @brief Multi-channel synchronized video player main View
/// @details Plays 4 cameras simultaneously and performs high-performance rendering with Metal.
struct MultiChannelPlayerView: View {
    // MARK: - Properties

    /// @var syncController
    /// @brief Synchronization controller
    /// @details Manages 4 VideoDecoders to provide synchronized frames.
    ///
    /// ## SyncController
    /// - ObservableObject responsible for multi-channel synchronized playback
    /// - Manages 4 VideoDecoders to provide synchronized frames
    ///
    /// ## @StateObject
    /// - Maintains a single instance throughout the View's lifecycle
    /// - syncController persists even if View is recreated
    ///
    /// **Synchronization role:**
    /// ```
    /// syncController
    ///     ├─ play() → Play all 4 decoders simultaneously
    ///     ├─ pause() → Pause all 4 decoders simultaneously
    ///     ├─ seekToTime() → Seek all 4 decoders simultaneously
    ///     └─ getSynchronizedFrames() → Return [Front, Rear, Left, Right] frames
    /// ```
    @StateObject private var syncController = SyncController()

    /// @var videoFile
    /// @brief Video file to play
    /// @details VideoFile object containing 4 channel information.
    ///
    /// ## VideoFile
    /// - Contains information for 4 channels (Front, Rear, Left, Right)
    /// - Retrieves filePath for each camera position from channels array
    ///
    /// **Example:**
    /// ```swift
    /// videoFile.channels = [
    ///     ChannelInfo(position: .front, filePath: "/front.mp4"),
    ///     ChannelInfo(position: .rear, filePath: "/rear.mp4"),
    ///     ChannelInfo(position: .left, filePath: "/left.mp4"),
    ///     ChannelInfo(position: .right, filePath: "/right.mp4")
    /// ]
    /// ```
    let videoFile: VideoFile

    /// @var layoutMode
    /// @brief Current layout mode
    /// @details Stores one of the layout modes: Grid, Focus, or Horizontal.
    ///
    /// ## LayoutMode
    /// - .grid: 2x2 grid layout (4 equal divisions)
    /// - .focus: Display only 1 selected channel large
    /// - .horizontal: Horizontal arrangement (1x4)
    ///
    /// **Layout transition example:**
    /// ```swift
    /// layoutMode = .grid  // Grid button clicked
    ///      ↓
    /// MetalVideoView receives updateNSView call
    ///      ↓
    /// renderer.setLayoutMode(.grid) → Passed to Metal Shader
    ///      ↓
    /// Rendered in 2x2 layout
    /// ```
    @State private var layoutMode: LayoutMode = .grid

    /// Selected camera position in focus mode
    ///
    /// ## CameraPosition
    /// - .front, .rear, .left, .right
    /// - Determines which channel to show large in Focus mode
    ///
    /// **Operation:**
    /// ```swift
    /// layoutMode = .focus
    /// focusedPosition = .front  // Show only Front camera large
    /// ```
    @State private var focusedPosition: CameraPosition = .front

    /// Whether to show control overlay
    ///
    /// ## Display conditions
    /// - true: Show controls (Play/Pause, Timeline, layout buttons, etc.)
    /// - false: Hide controls (after 3 seconds in fullscreen mode)
    ///
    /// **Operation:**
    /// ```swift
    /// if showControls || isHovering {
    ///     controlsOverlay  // Show controls
    /// }
    /// ```
    @State private var showControls = true

    /// Mouse hover state
    ///
    /// ## .onHover { hovering in ... }
    /// - hovering == true: Mouse is over the View
    /// - hovering == false: Mouse has left the View
    ///
    /// **Role:**
    /// - Show controls when mouse is inside View
    /// - Prevent auto-hide controls in fullscreen mode
    @State private var isHovering = false

    /// Renderer reference (for screenshot capture)
    ///
    /// ## MultiChannelRenderer
    /// - Metal-based video renderer
    /// - Save screenshot with captureAndSave() method
    ///
    /// **Screenshot capture:**
    /// ```swift
    /// renderer?.captureAndSave(format: .png, timestamp: Date(), ...)
    /// ```
    @State private var renderer: MultiChannelRenderer?

    /// Video transformation service
    ///
    /// ## VideoTransformationService
    /// - Singleton service (.shared)
    /// - Manages video transformation parameters like brightness, zoom, flip
    ///
    /// ## @ObservedObject
    /// - Observes changes to transformationService
    /// - View automatically re-renders when transformations value changes
    ///
    /// **Applying transformation:**
    /// ```swift
    /// transformationService.setBrightness(0.5)  // Increase brightness
    ///      ↓
    /// Metal Shader reads transformations.brightness
    ///      ↓
    /// Apply brightness effect to video
    /// ```
    @ObservedObject private var transformationService = VideoTransformationService.shared

    /// Whether to show transformation controls
    ///
    /// ## showTransformControls
    /// - true: Show Brightness, Zoom, Flip sliders
    /// - false: Hide sliders (default)
    ///
    /// **Toggle:**
    /// ```swift
    /// Button(action: { showTransformControls.toggle() }) {
    ///     Image(systemName: "slider.horizontal.3")
    /// }
    /// ```
    @State private var showTransformControls = false

    /// Fullscreen mode state
    ///
    /// ## isFullscreen
    /// - true: Fullscreen mode (enable auto-hide controls)
    /// - false: Normal mode (always show controls)
    ///
    /// **Entering/exiting fullscreen:**
    /// ```swift
    /// toggleFullscreen()
    ///      ↓
    /// window.toggleFullScreen(nil)  // macOS API
    ///      ↓
    /// isFullscreen.toggle()
    /// ```
    @State private var isFullscreen = false

    /// Auto-hide controls timer
    ///
    /// ## Timer
    /// - Auto-hide controls after 3 seconds in fullscreen mode
    /// - Reset timer when mouse movement is detected
    ///
    /// **Operation:**
    /// ```swift
    /// resetControlsTimer()
    ///      ↓
    /// Timer.scheduledTimer(withTimeInterval: 3.0) {
    ///     showControls = false  // Hide after 3 seconds
    /// }
    /// ```
    @State private var controlsTimer: Timer?

    /// List of available displays
    ///
    /// ## NSScreen.screens
    /// - Array of all connected displays in macOS
    /// - Select fullscreen target in multi-monitor environment
    ///
    /// **Example:**
    /// ```swift
    /// availableDisplays = [
    ///     NSScreen(main display, 1920x1080),
    ///     NSScreen(external display, 2560x1440)
    /// ]
    /// ```
    @State private var availableDisplays: [NSScreen] = []

    /// Selected display for fullscreen
    ///
    /// ## selectedDisplay
    /// - Default: NSScreen.main (main display)
    /// - User can select different display
    @State private var selectedDisplay: NSScreen?

    /// Whether to show GPS overlay
    ///
    /// ## showGPSOverlay
    /// - true: Show GPS HUD and map
    /// - false: Hide GPS information
    @State private var showGPSOverlay = AppSettings.shared.showGPSOverlayByDefault

    /// Whether to show metadata overlay
    ///
    /// ## showMetadataOverlay
    /// - true: Show metadata like speed, coordinates
    /// - false: Hide metadata
    @State private var showMetadataOverlay = AppSettings.shared.showMetadataOverlayByDefault

    // MARK: - Body

    /// Main layout of MultiChannelPlayerView
    ///
    /// ## ZStack structure
    /// - Stack multiple Views on top of each other (z-index order)
    /// - Bottom: MetalVideoView (video rendering)
    /// - Middle: GPS map, G-Sensor graph overlay
    /// - Top: Control UI (play button, timeline, etc.)
    ///
    /// **Layer structure:**
    /// ```
    /// ┌─────────────────────────────┐
    /// │  controlsOverlay (top)      │ ← Semi-transparent controls
    /// ├─────────────────────────────┤
    /// │  GraphOverlayView (middle2) │ ← G-Sensor graph
    /// ├─────────────────────────────┤
    /// │  MapOverlayView (middle1)   │ ← GPS map
    /// ├─────────────────────────────┤
    /// │  MetalVideoView (bottom)    │ ← Video rendering
    /// └─────────────────────────────┘
    /// ```
    var body: some View {
        ZStack {
            /// Metal-based video rendering View
            ///
            /// ## MetalVideoView
            /// - Wraps MTKView with NSViewRepresentable
            /// - High-performance rendering using Metal GPU
            /// - Retrieves and displays synchronized frames from syncController
            ///
            /// **Rendering flow:**
            /// ```
            /// MTKView.draw(in:) called (60 FPS)
            ///      ↓
            /// syncController.getSynchronizedFrames()
            ///      ↓
            /// renderer.render(frames: [...], to: drawable)
            ///      ↓
            /// Execute Metal Shader → GPU rendering
            ///      ↓
            /// Display on screen
            /// ```
            MetalVideoView(
                syncController: syncController,
                layoutMode: layoutMode,
                focusedPosition: focusedPosition,
                onRendererCreated: { renderer = $0 }  // Store renderer reference
            )

            /// GPS map overlay (conditional rendering)
            ///
            /// ## MapOverlayView
            /// - Display minimap at bottom left
            /// - Draw GPS path in real-time (blue line)
            /// - Show current position (red dot)
            /// - Only shown when showGPSOverlay == true
            if showGPSOverlay {
                MapOverlayView(
                    gpsService: syncController.gpsService,
                    gsensorService: syncController.gsensorService,
                    currentTime: syncController.currentTime
                )
            }

            /// Metadata overlay (conditional rendering)
            ///
            /// ## MetadataOverlayView
            /// - Display speedometer, GPS coordinates, altitude on left side
            /// - Only shown when showMetadataOverlay == true
            if showMetadataOverlay {
                MetadataOverlayView(
                    videoFile: videoFile,
                    currentTime: syncController.currentTime
                )
            }

            /// G-Sensor graph overlay
            ///
            /// ## GraphOverlayView
            /// - Display acceleration graph at bottom right
            /// - Show X/Y/Z axis data in real-time graph
            /// - Highlight when impact event detected
            GraphOverlayView(
                gsensorService: syncController.gsensorService,
                currentTime: syncController.currentTime
            )

            /// Control overlay (conditional rendering)
            ///
            /// ## Display conditions
            /// - showControls == true OR isHovering == true
            /// - Fullscreen mode: Auto-hide after 3 seconds
            /// - Normal mode: Always show
            ///
            /// ## .transition(.opacity)
            /// - Fade in/out animation when showing/hiding controls
            if showControls || isHovering {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        /// ## .onAppear
        /// - Called once when View appears on screen
        /// - Load video file and detect displays
        .onAppear {
            loadVideoFile()            // Load video file
            detectAvailableDisplays()  // Detect connected displays
        }
        /// ## .onDisappear
        /// - Called when View disappears from screen
        /// - Clean up resources (stop playback, invalidate timer)
        .onDisappear {
            syncController.stop()      // Stop playback
            controlsTimer?.invalidate()  // Invalidate timer
        }
        /// ## .onHover { hovering in ... }
        /// - Detect if mouse is over the View
        /// - hovering == true: Mouse entered the View
        /// - hovering == false: Mouse left the View
        ///
        /// **Operation:**
        /// ```
        /// Mouse moves into View
        ///      ↓
        /// isHovering = true
        ///      ↓
        /// showControls = true (show controls)
        ///      ↓
        /// resetControlsTimer() (reset auto-hide timer)
        /// ```
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                // Show controls when mouse enters
                showControls = true
                resetControlsTimer()
            }
        }
        /// ## .gesture(DragGesture(minimumDistance: 0))
        /// - minimumDistance: 0 → Detect even with just click (no drag needed)
        /// - Detect mouse movement to show controls
        ///
        /// **Operation:**
        /// ```
        /// Mouse moves (or clicks)
        ///      ↓
        /// .onChanged { _ in ... } called
        ///      ↓
        /// showControls = true
        ///      ↓
        /// resetControlsTimer() (reset 3 second timer)
        /// ```
        .gesture(
            // Track mouse movement to show controls
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    showControls = true
                    resetControlsTimer()
                }
        )
        /// ## .onReceive(NotificationCenter...)
        /// - Subscribe to macOS system events
        /// - Detect fullscreen enter/exit, display changes
        ///
        /// ### NSWindow.willEnterFullScreenNotification
        /// - Notification just before entering fullscreen mode
        /// - Set isFullscreen = true
        /// - Start auto-hide controls timer
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
            infoLog("[MultiChannelPlayerView] Entering fullscreen mode")
            resetControlsTimer()
        }
        /// ### NSWindow.willExitFullScreenNotification
        /// - Notification just before exiting fullscreen mode
        /// - Set isFullscreen = false
        /// - Always show controls (disable auto-hide)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
            showControls = true
            controlsTimer?.invalidate()
            infoLog("[MultiChannelPlayerView] Exiting fullscreen mode")
        }
        /// ### NSApplication.didChangeScreenParametersNotification
        /// - Notification for display configuration change
        /// - Monitor connect/disconnect, resolution change, etc.
        /// - Re-detect availableDisplays
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            detectAvailableDisplays()
            infoLog("[MultiChannelPlayerView] Screen configuration changed")
        }
    }

    // MARK: - Controls Overlay

    /// Control overlay View
    ///
    /// ## Structure
    /// - Top bar: Layout buttons + Transform button + Channel indicators
    /// - (Conditional) Transform controls: Brightness/Zoom/Flip sliders
    /// - Bottom bar: Timeline + Playback controls
    ///
    /// **Layout:**
    /// ```
    /// ┌────────────────────────────────────────────────┐
    /// │ [Grid][Focus][Horizontal]  [Transform]  [F][R] │ ← Top bar
    /// │ [Brightness ━━━━] [Zoom ━━━━] [Flip H] [Reset]│ ← Transform controls (showTransformControls)
    /// │                                                │
    /// │                 (video)                        │
    /// │                                                │
    /// │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ ← Timeline
    /// │ [▶] [⏪10] [⏩10]  [1.0x]  [📷] [⛶]           │ ← Playback controls
    /// └────────────────────────────────────────────────┘
    /// ```
    private var controlsOverlay: some View {
        VStack {
            /// Top bar: Layout and transformation controls
            VStack(spacing: 8) {
                HStack {
                    /// Layout buttons (Grid, Focus, Horizontal)
                    layoutControls

                    Spacer()

                    /// Transform toggle button
                    ///
                    /// ## Operation
                    /// - Toggle showTransformControls on click
                    /// - true: Show transformation sliders (brightness, zoom, flip)
                    /// - false: Hide transformation sliders
                    ///
                    /// **Icon colors:**
                    /// - showTransformControls == true: White + blue background
                    /// - showTransformControls == false: Semi-transparent white
                    Button(action: { showTransformControls.toggle() }) {
                        Image(systemName: showTransformControls ? "slider.horizontal.3" : "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(showTransformControls ? .white : .white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(showTransformControls ? Color.accentColor : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Video Transformations")

                    Spacer()
                        .frame(width: 12)

                    /// GPS overlay toggle button
                    ///
                    /// ## Operation
                    /// - Toggle showGPSOverlay on click
                    /// - true: Show GPS HUD, map overlay
                    /// - false: Hide GPS information
                    Button(action: { showGPSOverlay.toggle() }) {
                        Image(systemName: showGPSOverlay ? "location.fill" : "location")
                            .font(.system(size: 18))
                            .foregroundColor(showGPSOverlay ? .white : .white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(showGPSOverlay ? Color.accentColor : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle GPS Overlay")

                    /// Metadata overlay toggle button
                    ///
                    /// ## Operation
                    /// - Toggle showMetadataOverlay on click
                    /// - true: Show metadata like speedometer, coordinates
                    /// - false: Hide metadata
                    Button(action: { showMetadataOverlay.toggle() }) {
                        Image(systemName: showMetadataOverlay ? "gauge.with.needle.fill" : "gauge.with.needle")
                            .font(.system(size: 18))
                            .foregroundColor(showMetadataOverlay ? .white : .white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(showMetadataOverlay ? Color.accentColor : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Metadata Overlay")

                    Spacer()
                        .frame(width: 12)

                    /// Channel indicators (F, R, L, R buttons)
                    channelIndicators
                }

                /// GPS HUD (conditional rendering)
                ///
                /// ## GPSInfoHUD
                /// - Only shown when showGPSOverlay == true
                /// - Display compact GPS information (speed, coordinates, altitude, satellites)
                /// - Includes debug information popover
                if showGPSOverlay {
                    GPSInfoHUD(
                        gpsService: syncController.gpsService,
                        currentTime: syncController.currentTime
                    )
                }

                /// Transform controls (conditional rendering)
                ///
                /// ## Only shown when showTransformControls == true
                /// - Brightness slider (-1.0 ~ 1.0)
                /// - Zoom slider (1.0x ~ 5.0x)
                /// - Flip Horizontal/Vertical buttons
                /// - Reset button (reset all transformations)
                if showTransformControls {
                    transformationControls
                }
            }
            .padding()
            /// ## LinearGradient background
            /// - Dark gradient at top (semi-transparent)
            /// - Becomes more transparent towards bottom
            /// - Maintains readability when controls overlap video
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.7), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            /// Bottom bar: Timeline and playback controls
            VStack(spacing: 12) {
                /// Timeline slider
                timelineView

                /// Playback control buttons
                HStack(spacing: 20) {
                    playbackControls
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding()
            /// ## LinearGradient background
            /// - Dark gradient at bottom (semi-transparent)
            /// - Becomes more transparent towards top
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Layout Controls

    /// Layout mode selection buttons
    ///
    /// ## Layout modes
    /// - Grid: 2x2 grid (4 equal divisions)
    /// - Focus: Only selected channel shown large
    /// - Horizontal: Horizontal arrangement (1x4)
    ///
    /// **Button operation:**
    /// ```swift
    /// ForEach(LayoutMode.allCases) { mode in
    ///     Button { layoutMode = mode }  // Change mode
    /// }
    /// ```
    ///
    /// **Rendering reflection:**
    /// ```
    /// layoutMode changed
    ///      ↓ @State → View re-render
    /// MetalVideoView.updateNSView() called
    ///      ↓
    /// renderer.setLayoutMode(layoutMode)
    ///      ↓
    /// Metal Shader recalculates layout
    ///      ↓
    /// Display with new layout on screen
    /// ```
    private var layoutControls: some View {
        HStack(spacing: 12) {
            ForEach(LayoutMode.allCases, id: \.self) { mode in
                Button(action: { layoutMode = mode }) {
                    Image(systemName: iconName(for: mode))
                        .font(.system(size: 18))
                        .foregroundColor(layoutMode == mode ? .white : .white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(layoutMode == mode ? Color.accentColor : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(mode.displayName)
            }
        }
    }

    /// Channel indicator buttons (F, R, L, R)
    ///
    /// ## Role
    /// - Display each camera position as a button
    /// - Switch to Focus mode for that channel on click
    ///
    /// **Button generation:**
    /// ```swift
    /// videoFile.channels.filter(\.isEnabled)  // Only enabled channels
    ///      ↓
    /// ForEach { channel in
    ///     Button(action: {
    ///         focusedPosition = channel.position  // Set focus
    ///         layoutMode = .focus                 // Switch to Focus mode
    ///     }) { ... }
    /// }
    /// ```
    ///
    /// **Button example:**
    /// ```
    /// [F] [R] [L] [R]  ← Front, Rear, Left, Right
    ///  ↑ Selected (blue background)
    /// ```
    private var channelIndicators: some View {
        HStack(spacing: 8) {
            ForEach(videoFile.channels.filter(\.isEnabled), id: \.position) { channel in
                Button(action: {
                    focusedPosition = channel.position
                    if layoutMode != .focus {
                        layoutMode = .focus
                    }
                }) {
                    Text(channel.position.shortName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            focusedPosition == channel.position && layoutMode == .focus
                                ? Color.accentColor
                                : Color.white.opacity(0.3)
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(channel.position.displayName)
            }
        }
    }

    // MARK: - Transformation Controls

    /// Video transformation controls (Brightness, Zoom, Flip)
    ///
    /// ## Transformation types
    /// - **Brightness**: -1.0 (darker) ~ 1.0 (brighter)
    /// - **Zoom**: 1.0x (original) ~ 5.0x (5x magnification)
    /// - **Flip Horizontal**: Left-right flip
    /// - **Flip Vertical**: Up-down flip
    ///
    /// ## VideoTransformationService
    /// - Manages transformation parameters as singleton service
    /// - Real-time application by reading transformations in Metal Shader
    ///
    /// **Transformation application flow:**
    /// ```
    /// User adjusts Brightness slider
    ///      ↓
    /// transformationService.setBrightness(0.5)
    ///      ↓
    /// transformationService.transformations.brightness = 0.5
    ///      ↓ @Published → View re-render
    /// Metal Shader reads transformations.brightness
    ///      ↓
    /// GPU applies brightness effect (add +0.5 to all pixels)
    ///      ↓
    /// Display brightened video on screen
    /// ```
    private var transformationControls: some View {
        VStack(spacing: 12) {
            /// First row: Brightness and Zoom
            HStack(spacing: 20) {
                /// Brightness control
                ///
                /// ## Slider + Binding
                /// - Two-way binding with Binding(get:, set:)
                /// - get: Read transformationService.transformations.brightness
                /// - set: Call transformationService.setBrightness($0)
                ///
                /// **Operation:**
                /// ```swift
                /// Drag slider
                ///      ↓
                /// set: { transformationService.setBrightness($0) } called
                ///      ↓
                /// transformations.brightness updated
                ///      ↓
                /// Immediately reflected in Metal Shader
                /// ```
                HStack(spacing: 8) {
                    /// Dark sun icon (minimum value indicator)
                    Image(systemName: "sun.min")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    /// Brightness slider (-1.0 ~ 1.0)
                    Slider(
                        value: Binding(
                            get: { transformationService.transformations.brightness },
                            set: { transformationService.setBrightness($0) }
                        ),
                        in: -1.0...1.0
                    )
                    .frame(width: 120)

                    /// Bright sun icon (maximum value indicator)
                    Image(systemName: "sun.max")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    /// Current brightness value text
                    ///
                    /// ## String(format: "%.2f", ...)
                    /// - Display up to 2 decimal places
                    /// - e.g.: 0.50, -0.75
                    Text(String(format: "%.2f", transformationService.transformations.brightness))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40)
                }

                /// Zoom control
                ///
                /// ## Zoom range
                /// - 1.0x: Original size
                /// - 5.0x: 5x magnification
                ///
                /// **Magnification principle:**
                /// ```
                /// zoomLevel = 2.0x
                ///      ↓
                /// Adjust texture coordinates in Metal Shader
                ///      ↓
                /// Magnify 2x from center
                ///      ↓
                /// Display magnified video on screen
                /// ```
                HStack(spacing: 8) {
                    /// Zoom out icon (minimum value indicator)
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    /// Zoom slider (1.0 ~ 5.0)
                    Slider(
                        value: Binding(
                            get: { transformationService.transformations.zoomLevel },
                            set: { transformationService.setZoomLevel($0) }
                        ),
                        in: 1.0...5.0
                    )
                    .frame(width: 120)

                    /// Zoom in icon (maximum value indicator)
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 20)

                    /// Current zoom level text
                    ///
                    /// ## String(format: "%.1fx", ...)
                    /// - 1 decimal place + "x" suffix
                    /// - e.g.: 1.0x, 2.5x
                    Text(String(format: "%.1fx", transformationService.transformations.zoomLevel))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40)
                }
            }

            /// Second row: Flip buttons and Reset
            HStack(spacing: 12) {
                /// Flip Horizontal button
                ///
                /// ## Left-right flip
                /// - Call toggleFlipHorizontal()
                /// - flipHorizontal == true: Left-right flip enabled (blue background)
                /// - flipHorizontal == false: Flip disabled (gray background)
                ///
                /// **Flip principle:**
                /// ```
                /// flipHorizontal = true
                ///      ↓
                /// Invert texture coordinates in Metal Shader (u = 1.0 - u)
                ///      ↓
                /// Display left-right flipped video
                /// ```
                Button(action: { transformationService.toggleFlipHorizontal() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 14))
                        Text("Flip H")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(
                        transformationService.transformations.flipHorizontal
                            ? Color.accentColor
                            : Color.white.opacity(0.2)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Flip Horizontal")

                /// Flip Vertical button
                ///
                /// ## Up-down flip
                /// - Call toggleFlipVertical()
                /// - flipVertical == true: Up-down flip enabled (blue background)
                /// - flipVertical == false: Flip disabled (gray background)
                ///
                /// **Flip principle:**
                /// ```
                /// flipVertical = true
                ///      ↓
                /// Invert texture coordinates in Metal Shader (v = 1.0 - v)
                ///      ↓
                /// Display up-down flipped video
                /// ```
                Button(action: { transformationService.toggleFlipVertical() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 14))
                        Text("Flip V")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(
                        transformationService.transformations.flipVertical
                            ? Color.accentColor
                            : Color.white.opacity(0.2)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Flip Vertical")

                Spacer()

                /// Reset button
                ///
                /// ## Reset all transformations
                /// - Call resetTransformations()
                /// - brightness = 0.0
                /// - zoomLevel = 1.0
                /// - flipHorizontal = false
                /// - flipVertical = false
                Button(action: { transformationService.resetTransformations() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                        Text("Reset")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 28)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Reset all transformations")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    // MARK: - Timeline

    /// Timeline View (playback progress bar + time display)
    ///
    /// ## Components
    /// - Progress bar: Shows current playback position (blue bar)
    /// - Time labels: Current time / Remaining time
    ///
    /// **Timeline operation:**
    /// ```
    /// User drags timeline
    ///      ↓
    /// DragGesture.onChanged { value in
    ///     position = value.location.x / geometry.size.width
    ///     time = position * syncController.duration
    ///     syncController.seekToTime(time)
    /// }
    ///      ↓
    /// All 4 channels seek to that time simultaneously
    ///      ↓
    /// Display frame at seeked position on screen
    /// ```
    private var timelineView: some View {
        VStack(spacing: 4) {
            /// Progress bar (clickable/draggable)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    /// Background (gray, full length)
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)

                    /// Progress (blue, up to playback position)
                    ///
                    /// ## width calculation
                    /// ```swift
                    /// width = geometry.size.width * syncController.playbackPosition
                    /// ```
                    ///
                    /// **Example:**
                    /// ```
                    /// geometry.size.width = 800px
                    /// playbackPosition = 0.5 (50%)
                    ///      ↓
                    /// width = 800 * 0.5 = 400px (blue up to half)
                    /// ```
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * syncController.playbackPosition, height: 4)
                }
                .cornerRadius(2)
                /// ## DragGesture(minimumDistance: 0)
                /// - minimumDistance: 0 → Can seek with just click (no drag needed)
                /// - .onChanged: Called continuously during drag
                ///
                /// **Seek calculation:**
                /// ```swift
                /// // User clicks at 75% position on timeline
                /// value.location.x = 600px
                /// geometry.size.width = 800px
                ///      ↓
                /// position = 600 / 800 = 0.75 (75%)
                ///      ↓
                /// time = 0.75 * 90 = 67.5 seconds
                ///      ↓
                /// syncController.seekToTime(67.5) → Seek to 67.5 seconds
                /// ```
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Validate before seeking to prevent EXC_BAD_ACCESS
                            guard syncController.channelCount > 0,
                                  syncController.duration > 0,
                                  geometry.size.width > 0 else {
                                debugLog("[MultiChannelPlayerView] Skipping timeline seek: invalid state (channelCount=\(syncController.channelCount), duration=\(syncController.duration), width=\(geometry.size.width))")
                                return
                            }

                            let position = Double(value.location.x / geometry.size.width)
                            let time = position * syncController.duration
                            syncController.seekToTime(time)
                        }
                )
            }
            .frame(height: 4)

            /// Time labels
            HStack {
                /// Current time (e.g.: "01:30")
                Text(syncController.currentTimeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                /// Remaining time (e.g.: "-00:30")
                Text(syncController.remainingTimeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Playback Controls

    /// Playback control buttons
    ///
    /// ## Button list
    /// - Play/Pause: Toggle play/pause
    /// - Seek backward: 10 seconds backward
    /// - Seek forward: 10 seconds forward
    /// - Speed: Playback speed menu (0.25x ~ 2.0x)
    /// - Buffer indicator: Show when buffering
    /// - Channel count: Display number of channels
    /// - Screenshot: Capture screenshot
    /// - Fullscreen: Toggle fullscreen
    private var playbackControls: some View {
        HStack(spacing: 20) {
            /// Play/Pause button
            ///
            /// ## Icon selection
            /// - .playing: "pause.fill" (pause icon)
            /// - .paused or .stopped: "play.fill" (play icon)
            ///
            /// **Operation:**
            /// ```
            /// Call togglePlayPause()
            ///      ↓
            /// syncController.togglePlayPause()
            ///      ↓
            /// All 4 decoders play/pause simultaneously
            /// ```
            Button(action: { syncController.togglePlayPause() }) {
                Image(systemName: syncController.playbackState == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .help(syncController.playbackState == .playing ? "Pause" : "Play")

            /// Seek backward button (10 seconds back)
            ///
            /// ## seekBySeconds(-10)
            /// - Subtract 10 seconds from current time
            /// - Move backward with negative value
            ///
            /// **Example:**
            /// ```
            /// currentTime = 30 seconds
            ///      ↓
            /// seekBySeconds(-10)
            ///      ↓
            /// seekToTime(20 seconds) → Seek to 20 seconds
            /// ```
            Button(action: { syncController.seekBySeconds(-10) }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Seek backward 10 seconds")

            /// Seek forward button (10 seconds forward)
            ///
            /// ## seekBySeconds(10)
            /// - Add 10 seconds to current time
            /// - Move forward with positive value
            ///
            /// **Example:**
            /// ```
            /// currentTime = 30 seconds
            ///      ↓
            /// seekBySeconds(10)
            ///      ↓
            /// seekToTime(40 seconds) → Seek to 40 seconds
            /// ```
            Button(action: { syncController.seekBySeconds(10) }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Seek forward 10 seconds")

            Spacer()

            /// Playback speed menu
            speedControl

            /// Buffering indicator
            ///
            /// ## isBuffering
            /// - true: Show ProgressView (loading spinner)
            /// - false: Don't show
            ///
            /// **Buffering moments:**
            /// - During seek
            /// - Frame decoding delay
            /// - Disk I/O wait
            if syncController.isBuffering {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            }

            /// Channel count display
            ///
            /// ## channelCount
            /// - Number of channels managed by syncController
            /// - e.g.: "4 channels"
            Text("\(syncController.channelCount) channels")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))

            Spacer()
                .frame(width: 20)

            /// Screenshot button
            ///
            /// ## captureScreenshot()
            /// - Save currently rendering frame as PNG
            /// - Filename: Blackbox_YYYYMMdd_HHmmss.png
            /// - Save location: User selection (Save Panel)
            Button(action: captureScreenshot) {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Capture Screenshot")

            /// Fullscreen toggle button
            ///
            /// ## toggleFullscreen()
            /// - Call window.toggleFullScreen(nil)
            /// - Toggle isFullscreen
            /// - Enable auto-hide controls in fullscreen mode
            ///
            /// **Icons:**
            /// - isFullscreen == true: "arrow.down.right.and.arrow.up.left" (shrink)
            /// - isFullscreen == false: "arrow.up.left.and.arrow.down.right" (expand)
            Button(action: toggleFullscreen) {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help(isFullscreen ? "Exit Fullscreen" : "Enter Fullscreen")
        }
    }

    // MARK: - Fullscreen

    /// Fullscreen toggle function
    ///
    /// ## Operation process
    /// ```
    /// 1. Get NSApplication.shared.keyWindow
    ///      ↓
    /// 2. Call window.toggleFullScreen(nil) (macOS API)
    ///      ↓
    /// 3. Toggle isFullscreen (true ↔ false)
    ///      ↓
    /// 4. Enter/exit fullscreen mode
    /// ```
    ///
    /// **Fullscreen mode features:**
    /// - Auto-hide controls (after 3 seconds)
    /// - Show controls on mouse movement
    /// - Can exit with Escape key
    private func toggleFullscreen() {
        /// Get currently active window
        ///
        /// ## NSApplication.shared.keyWindow
        /// - Current active window in macOS
        /// - If nil: No window or inactive state
        guard let window = NSApplication.shared.keyWindow else {
            warningLog("[MultiChannelPlayerView] No key window available for fullscreen toggle")
            return
        }

        /// Toggle fullscreen
        ///
        /// ## window.toggleFullScreen(nil)
        /// - Switch to fullscreen with macOS API
        /// - nil: sender parameter (usually pass nil)
        ///
        /// **Transition process:**
        /// ```
        /// Normal mode (800x600 window)
        ///      ↓
        /// Call toggleFullScreen(nil)
        ///      ↓
        /// Fullscreen mode (entire 1920x1080 screen)
        /// ```
        window.toggleFullScreen(nil)
        isFullscreen.toggle()

        infoLog("[MultiChannelPlayerView] Fullscreen mode: \(isFullscreen)")
    }

    // MARK: - Auto-hide Controls

    /// Reset auto-hide controls timer
    ///
    /// ## Operation process
    /// ```
    /// 1. Invalidate existing timer
    ///      ↓
    /// 2. Exit if not fullscreen mode (no auto-hide in normal mode)
    ///      ↓
    /// 3. Create 3-second timer
    ///      ↓ After 3 seconds (no mouse movement)
    /// 4. showControls = false (hide controls)
    /// ```
    ///
    /// **Call timing:**
    /// - Mouse movement detected
    /// - Mouse hover (entering View)
    /// - Entering fullscreen
    private func resetControlsTimer() {
        /// Invalidate existing timer
        ///
        /// ## controlsTimer?.invalidate()
        /// - Stop and release previous timer
        /// - No action if timer is nil (?. operator)
        controlsTimer?.invalidate()

        /// Don't auto-hide if not fullscreen mode
        ///
        /// ## guard isFullscreen
        /// - Always show controls in normal mode
        /// - Enable auto-hide only in fullscreen mode
        guard isFullscreen else {
            return
        }

        /// Create 3-second timer
        ///
        /// ## Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false)
        /// - Execute closure after 3.0 seconds
        /// - repeats: false → Execute once (no repeat)
        ///
        /// **Timer operation:**
        /// ```
        /// Call resetControlsTimer()
        ///      ↓
        /// Wait 3 seconds
        ///      ↓ No mouse movement
        /// showControls = false (fade-out animation)
        ///      ↓
        /// Hide controls
        ///      ↓ Mouse moves again
        /// Call resetControlsTimer() → Reset timer
        /// ```
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showControls = false
            }
        }
    }

    // MARK: - Screenshot

    /// Screenshot capture function
    ///
    /// ## Capture process
    /// ```
    /// 1. Verify renderer exists
    ///      ↓
    /// 2. Generate filename (Blackbox_YYYYMMdd_HHmmss)
    ///      ↓
    /// 3. Call renderer.captureAndSave()
    ///      ↓
    /// 4. Convert current rendering frame to PNG in Metal
    ///      ↓
    /// 5. Show Save Panel → User selects save location
    ///      ↓
    /// 6. Save PNG file
    /// ```
    ///
    /// **Capture contents:**
    /// - Currently rendering 4 channel videos
    /// - Applied layout mode (Grid/Focus/Horizontal)
    /// - Applied video transformations (Brightness/Zoom/Flip)
    /// - Timestamp overlay (optional)
    private func captureScreenshot() {
        /// Verify renderer exists
        ///
        /// ## guard let renderer
        /// - Output warning log and exit if renderer is nil
        /// - Metal renderer not initialized state
        guard let renderer = renderer else {
            warningLog("[MultiChannelPlayerView] Renderer not available for screenshot")
            return
        }

        infoLog("[MultiChannelPlayerView] Capturing screenshot")

        /// Generate filename (with timestamp)
        ///
        /// ## DateFormatter
        /// - dateFormat: "yyyyMMdd_HHmmss" (e.g.: 20240115_143015)
        /// - Generate unique filename with current time
        ///
        /// **Filename example:**
        /// ```
        /// Date() = 2024-01-15 14:30:15
        ///      ↓
        /// dateString = "20240115_143015"
        ///      ↓
        /// filename = "Blackbox_20240115_143015"
        ///      ↓
        /// Save: Blackbox_20240115_143015.png
        /// ```
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "Blackbox_\(dateString)"

        /// Capture and save screenshot
        ///
        /// ## renderer.captureAndSave()
        /// - format: .png (save in PNG format)
        /// - timestamp: Date() (capture time)
        /// - videoTimestamp: syncController.currentTime (video playback time)
        /// - defaultFilename: filename (default filename)
        ///
        /// **Capture process:**
        /// ```
        /// Get current drawable from Metal
        ///      ↓
        /// Convert drawable.texture to CGImage
        ///      ↓
        /// Encode CGImage to PNG data
        ///      ↓
        /// Show NSSavePanel (user selects save location)
        ///      ↓
        /// Save PNG file to selected path
        /// ```
        renderer.captureAndSave(
            format: .png,
            timestamp: Date(),
            videoTimestamp: syncController.currentTime,
            defaultFilename: filename
        )
    }

    /// Playback speed menu
    ///
    /// ## Speed options
    /// - 0.25x, 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x
    ///
    /// **Speed change operation:**
    /// ```
    /// Select 1.5x from Menu
    ///      ↓
    /// syncController.playbackSpeed = 1.5
    ///      ↓
    /// Readjust Timer interval for 4 decoders
    ///      ↓
    /// interval = (1.0 / frameRate) / 1.5 (1.5x faster)
    ///      ↓
    /// Play at 1.5x speed
    /// ```
    private var speedControl: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: { syncController.playbackSpeed = speed }) {
                    HStack {
                        Text(String(format: "%.2fx", speed))
                        /// Show checkmark for currently selected speed
                        if syncController.playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(syncController.playbackSpeedString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 28)
                .background(Color.white.opacity(0.2))
                .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .help("Playback speed")
    }

    // MARK: - Helper Methods

    /// Return icon name for layout mode
    ///
    /// ## SF Symbols
    /// - .grid: "square.grid.2x2" (2x2 grid)
    /// - .focus: "rectangle.inset.filled.and.person.filled" (person focus)
    /// - .horizontal: "rectangle.split.3x1" (horizontal split)
    private func iconName(for mode: LayoutMode) -> String {
        switch mode {
        case .grid:
            return "square.grid.2x2"
        case .focus:
            return "rectangle.inset.filled.and.person.filled"
        case .horizontal:
            return "rectangle.split.3x1"
        }
    }

    /// Video file loading function
    ///
    /// ## Loading process
    /// ```
    /// 1. Call syncController.loadVideoFile(videoFile)
    ///      ↓
    /// 2. Get 4 channels from videoFile.channels
    ///      ↓
    /// 3. Create and initialize VideoDecoder for each channel
    ///      ↓
    /// 4. Initialize GPS/G-Sensor service
    ///      ↓
    /// 5. Load first frame (all channels)
    ///      ↓
    /// 6. Ready to play (playbackState = .paused)
    /// ```
    ///
    /// **Error handling:**
    /// - File not found: Output errorLog
    /// - Decoder initialization failed: Output errorLog
    /// - Insufficient channels: Output errorLog
    private func loadVideoFile() {
        do {
            infoLog("[MultiChannelPlayerView] Loading video file: \(videoFile.baseFilename)")
            try syncController.loadVideoFile(videoFile)
            infoLog("[MultiChannelPlayerView] Video file loaded successfully. Channels: \(syncController.channelCount)")
        } catch {
            errorLog("[MultiChannelPlayerView] Failed to load video file: \(error)")
        }
    }

    // MARK: - Display Management

    /// Detect available displays
    ///
    /// ## NSScreen.screens
    /// - Array of all connected displays in macOS
    /// - Includes all displays: main, external, airplay, etc.
    ///
    /// **Display information:**
    /// - frame: Screen size and position (CGRect)
    /// - localizedName: Display name (e.g.: "Built-in Retina Display")
    ///
    /// **Example:**
    /// ```
    /// Display 1: Built-in Retina Display, frame: (0.0, 0.0, 2560.0, 1600.0)
    /// Display 2: LG UltraWide, frame: (2560.0, 0.0, 3440.0, 1440.0)
    /// ```
    private func detectAvailableDisplays() {
        availableDisplays = NSScreen.screens
        selectedDisplay = NSScreen.main

        let displayCount = availableDisplays.count
        infoLog("[MultiChannelPlayerView] Detected \(displayCount) display(s)")

        /// Log each display information
        for (index, screen) in availableDisplays.enumerated() {
            let frame = screen.frame
            let name = screen.localizedName
            debugLog("[MultiChannelPlayerView] Display \(index + 1): \(name), frame: \(frame)")
        }
    }
}

// MARK: - Metal Video View

/// Metal-based video rendering View
///
/// ## NSViewRepresentable
/// - Integrates AppKit's NSView (MTKView) into SwiftUI
/// - makeNSView: Create and initially configure MTKView (called once)
/// - updateNSView: Update NSView when SwiftUI state changes (called multiple times)
/// - makeCoordinator: Create Coordinator for delegate handling
///
/// ## MTKView
/// - View class from Metal Kit
/// - High-performance rendering using Metal GPU
/// - Capable of 60 FPS rendering
///
/// **Rendering pipeline:**
/// ```
/// MTKView
///     ↓ draw(in:) called (60 FPS)
/// Coordinator (MTKViewDelegate)
///     ↓
/// syncController.getSynchronizedFrames()
///     ↓ [FrontFrame, RearFrame, LeftFrame, RightFrame]
/// MultiChannelRenderer.render()
///     ↓ Execute Metal Shader
/// GPU rendering
///     ↓
/// Store rendering result in drawable
///     ↓
/// Display on screen (vsync synchronized)
/// ```
private struct MetalVideoView: NSViewRepresentable {
    // MARK: - Properties

    /// Synchronization controller
    ///
    /// ## @ObservedObject
    /// - Observe changes to syncController
    /// - Update View when currentTime, playbackState, etc. change
    @ObservedObject var syncController: SyncController

    /// Layout mode
    ///
    /// ## LayoutMode
    /// - .grid, .focus, .horizontal
    /// - Passed to Coordinator in updateNSView
    let layoutMode: LayoutMode

    /// Focused camera position
    ///
    /// ## CameraPosition
    /// - Determines which channel to show large in Focus mode
    let focusedPosition: CameraPosition

    /// Renderer creation callback
    ///
    /// ## (MultiChannelRenderer) -> Void
    /// - Pass to parent View when Renderer is created
    /// - Used for screenshot capture
    let onRendererCreated: (MultiChannelRenderer) -> Void

    // MARK: - NSViewRepresentable

    /// Create and initially configure MTKView
    ///
    /// ## makeNSView
    /// - Called only once during View lifecycle
    /// - Create MTKView and configure Metal device
    ///
    /// **MTKView configuration:**
    /// - device: Metal device (GPU)
    /// - delegate: Coordinator (rendering logic)
    /// - preferredFramesPerSecond: Target 30 FPS
    /// - framebufferOnly: true (optimization)
    /// - clearColor: Black (0, 0, 0, 1)
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()

        /// Create Metal device
        ///
        /// ## MTLCreateSystemDefaultDevice()
        /// - Get system default GPU device
        /// - M1/M2 Mac: Apple Silicon GPU
        /// - Intel Mac: AMD/Intel GPU
        mtkView.device = MTLCreateSystemDefaultDevice()

        /// Set delegate
        ///
        /// ## mtkView.delegate = context.coordinator
        /// - Coordinator implements draw(in:) method
        /// - MTKView calls draw(in:) when ready to render
        mtkView.delegate = context.coordinator

        /// Set rendering mode
        ///
        /// ## enableSetNeedsDisplay = false
        /// - false: Automatic rendering mode (according to preferredFramesPerSecond)
        /// - true: Manual rendering mode (requires setNeedsDisplay() call)
        mtkView.enableSetNeedsDisplay = false

        /// Set pause state
        ///
        /// ## isPaused = false
        /// - false: Rendering enabled (continue draw calls)
        /// - true: Rendering paused
        mtkView.isPaused = false

        /// Set target frame rate
        ///
        /// ## preferredFramesPerSecond = 30
        /// - Render at 30 FPS (30 draw calls per second)
        /// - 60 FPS possible but videos are usually 30 FPS
        mtkView.preferredFramesPerSecond = 30  // Set target frame rate

        /// Framebuffer optimization
        ///
        /// ## framebufferOnly = true
        /// - true: Use Framebuffer only for screen display (no reading)
        /// - Performance improvement (GPU memory optimization)
        mtkView.framebufferOnly = true

        /// Set background color
        ///
        /// ## clearColor = MTLClearColor(r: 0, g: 0, b: 0, a: 1)
        /// - Black background (shown before video loads)
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        return mtkView
    }

    /// Update NSView (when SwiftUI state changes)
    ///
    /// ## updateNSView
    /// - Called when SwiftUI's @State, @Binding changes
    /// - layoutMode, focusedPosition changes → Pass to Coordinator
    ///
    /// **Call timing:**
    /// ```
    /// layoutMode = .focus  // @State change
    ///      ↓
    /// SwiftUI calls updateNSView
    ///      ↓
    /// context.coordinator.layoutMode = .focus
    ///      ↓
    /// Render with new layout on next draw(in:) call
    /// ```
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.layoutMode = layoutMode
        context.coordinator.focusedPosition = focusedPosition
    }

    /// Create Coordinator
    ///
    /// ## makeCoordinator
    /// - Create Coordinator implementing MTKViewDelegate
    /// - Maintain single instance during View lifecycle
    ///
    /// **Coordinator role:**
    /// - Implement MTKView's rendering logic (draw(in:))
    /// - Create and manage MultiChannelRenderer
    /// - Fetch and render synchronized frames
    func makeCoordinator() -> Coordinator {
        Coordinator(
            syncController: syncController,
            layoutMode: layoutMode,
            focusedPosition: focusedPosition,
            onRendererCreated: onRendererCreated
        )
    }

    // MARK: - Coordinator

    /// Coordinator class implementing MTKViewDelegate
    ///
    /// ## Coordinator pattern
    /// - Bridge connecting SwiftUI View and AppKit Delegate
    /// - Inherits NSObject (Objective-C compatibility)
    /// - Implements MTKViewDelegate protocol
    ///
    /// **Role:**
    /// - Implement rendering logic with draw(in:) method
    /// - Perform Metal rendering with MultiChannelRenderer
    /// - Fetch synchronized frames from SyncController
    class Coordinator: NSObject, MTKViewDelegate {
        /// Synchronization controller reference
        let syncController: SyncController

        /// Current layout mode
        var layoutMode: LayoutMode

        /// Focused camera position
        var focusedPosition: CameraPosition

        /// Metal renderer
        var renderer: MultiChannelRenderer?

        /// Initialize Coordinator
        ///
        /// ## init
        /// - Store syncController, layoutMode, focusedPosition
        /// - Create MultiChannelRenderer
        /// - Call onRendererCreated callback (pass renderer to parent View)
        init(
            syncController: SyncController,
            layoutMode: LayoutMode,
            focusedPosition: CameraPosition,
            onRendererCreated: @escaping (MultiChannelRenderer) -> Void
        ) {
            self.syncController = syncController
            self.layoutMode = layoutMode
            self.focusedPosition = focusedPosition
            super.init()

            /// Create MultiChannelRenderer
            ///
            /// ## MultiChannelRenderer()
            /// - Initialize Metal rendering engine
            /// - Load and compile Shader
            /// - Configure rendering pipeline
            if let renderer = MultiChannelRenderer() {
                self.renderer = renderer
                onRendererCreated(renderer)  // Pass to parent View
            }
        }

        /// Called when MTKView size changes
        ///
        /// ## mtkView(_:drawableSizeWillChange:)
        /// - Called on window resize, fullscreen transition
        /// - Reconfigure rendering resources if needed
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            debugLog("[MetalVideoView] Drawable size changed to: \(size.width) x \(size.height)")
            // Renderer will automatically adapt to the new drawable size on next render
            // No need to pause or stop playback
        }

        /// Rendering function (called at 60 FPS)
        ///
        /// ## draw(in view:)
        /// - Automatically called when MTKView is ready to render
        /// - Call frequency determined by preferredFramesPerSecond (30 FPS)
        ///
        /// **Rendering process:**
        /// ```
        /// 1. Get drawable (rendering target)
        ///      ↓
        /// 2. Configure renderer (layoutMode, focusedPosition)
        ///      ↓
        /// 3. syncController.getSynchronizedFrames() → Get synchronized frames
        ///      ↓
        /// 4. renderer.render(frames, to: drawable) → Metal rendering
        ///      ↓
        /// 5. drawable.present() → Display on screen (vsync synchronized)
        /// ```
        func draw(in view: MTKView) {
            /// Verify drawable and renderer exist
            ///
            /// ## guard let drawable, renderer
            /// - drawable: Buffer to store rendering result
            /// - renderer: Metal rendering engine
            /// - Skip rendering if either is nil
            guard let drawable = view.currentDrawable,
                  let renderer = renderer else {
                debugLog("[MetalVideoView] Draw skipped: drawable or renderer is nil")
                return
            }

            /// Update Renderer configuration
            ///
            /// ## setLayoutMode, setFocusedPosition
            /// - Pass current layout mode to renderer
            /// - Metal Shader reads these settings for rendering
            renderer.setLayoutMode(layoutMode)
            renderer.setFocusedPosition(focusedPosition)

            /// Get synchronized frames
            ///
            /// ## getSynchronizedFrames()
            /// - Return current time frames for 4 channels
            /// - [FrontFrame, RearFrame, LeftFrame, RightFrame]
            let frames = syncController.getSynchronizedFrames()

            /// Skip rendering if no frames
            ///
            /// ## frames.isEmpty
            /// - Before video loads
            /// - Decoding delay
            /// - Reached EOF
            if frames.isEmpty {
                // No frames available yet, just return (black screen will be shown)
                return
            }

            debugLog("[MetalVideoView] Rendering \(frames.count) frames at time \(String(format: "%.2f", syncController.currentTime))")

            /// Perform Metal rendering
            ///
            /// ## renderer.render(frames:to:drawableSize:)
            /// - frames: Synchronized frame array
            /// - drawable: Buffer to store rendering result
            /// - drawableSize: Rendering size
            ///
            /// **Rendering internals:**
            /// ```
            /// 1. Convert each frame to Metal Texture
            ///      ↓
            /// 2. Execute Vertex Shader (calculate screen coordinates)
            ///      ↓
            /// 3. Execute Fragment Shader (calculate pixel colors)
            ///      ↓ Apply Brightness, Zoom, Flip
            /// 4. Store rendering result in drawable.texture
            ///      ↓
            /// 5. drawable.present() → Display on screen
            /// ```
            renderer.render(
                frames: frames,
                to: drawable,
                drawableSize: view.drawableSize
            )
        }
    }
}

// MARK: - Preview

// Preview temporarily disabled - requires sample data
// struct MultiChannelPlayerView_Previews: PreviewProvider {
//     static var previews: some View {
//         MultiChannelPlayerView(videoFile: sampleVideoFile)
//             .frame(width: 1280, height: 720)
//     }
// }
