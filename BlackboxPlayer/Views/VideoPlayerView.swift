/// @file VideoPlayerView.swift
/// @brief Main video player View
/// @author BlackboxPlayer Development Team
/// @details Implements the main player View for playing blackbox videos.
///          Provides keyboard shortcuts, fullscreen mode, and auto-hide controls functionality.

/*
 【VideoPlayerView Overview】

 This file implements the main player View for playing blackbox videos.


 ┌──────────────────────────────────────────────────────┐
 │                                                      │
 │                                                      │
 │              📹 Video Display Area                   │ ← Video frame display
 │           (VideoFrameView)                           │
 │                                                      │
 │                                                      │
 ├──────────────────────────────────────────────────────┤
 │ ⏯️  ⏮️ ⏭️  [━━━━━━━━━━━━━━●─────]  2:34 / 5:00  🔊 │ ← Playback controls
 └──────────────────────────────────────────────────────┘
 (Shown on mouse hover, auto-hide after 3 seconds)


 【Key Features】

 1. Video Playback
 - AVFoundation-based video decoding
 - Frame-by-frame rendering
 - Support for various codecs

 2. User Interface
 - Show controls on mouse hover
 - Auto-hide after 3 seconds (when playing only)
 - Fullscreen mode

 3. Keyboard Shortcuts
 - Space: Play/Pause
 - ←/→: Seek backward/forward 5 seconds
 - ↑/↓: Volume adjustment
 - F: Toggle fullscreen
 - ESC: Exit fullscreen

 4. State-based UI
 - Loading: Show spinner
 - Error: Display error message
 - Placeholder: No video loaded


 【SwiftUI + AppKit Integration】

 This file uses both SwiftUI and macOS AppKit:

 **SwiftUI Usage:**
 - View layout and rendering
 - State management (@State, @StateObject)
 - Animations and transitions

 **AppKit Usage:**
 - Keyboard event monitoring (NSEvent)
 - Fullscreen window control (NSWindow)
 - Native macOS feature access

 Integration benefits:
 ✓ SwiftUI's declarative UI
 ✓ AppKit's powerful system access
 ✓ Best user experience


 【MVVM Pattern】

 This file follows the MVVM (Model-View-ViewModel) pattern:

 ```
 Model (VideoFile)
 ↓ Data
 ViewModel (VideoPlayerViewModel)
 ↓ State & Business Logic
 View (VideoPlayerView)
 ↓ UI Rendering
 ```

 Responsibility distribution:
 - Model: Video file data
 - ViewModel: Playback logic, state management
 - View: UI display, user input forwarding


 【Usage Examples】

 ```swift
 // 1. Standalone usage
 VideoPlayerView(videoFile: someVideoFile)

 // 2. Display as Sheet
 .sheet(isPresented: $showPlayer) {
 VideoPlayerView(videoFile: selectedFile)
 }

 // 3. Transition with NavigationLink
 NavigationLink(destination: VideoPlayerView(videoFile: file)) {
 Text("Play Video")
 }
 ```


 【Related Files】

 - VideoPlayerViewModel.swift: Playback logic and state management
 - PlayerControlsView.swift: Playback controls UI
 - VideoFrame.swift: Video frame data structure
 - VideoFile.swift: Video file metadata

 */

import SwiftUI
import AppKit

/// @struct VideoPlayerView
/// @brief Main video player View
/// @details Main player providing video playback functionality.
///          Supports keyboard shortcuts, fullscreen mode, and auto-hide controls.
///
/// **Key Features:**
/// - Video frame rendering
/// - Playback controls (auto-hide)
/// - Keyboard shortcuts
/// - Fullscreen mode
///
/// **Usage Example:**
/// ```swift
/// VideoPlayerView(videoFile: selectedVideoFile)
/// ```
///
/// **Associated Types:**
/// - `VideoFile`: Video file to play
/// - `VideoPlayerViewModel`: Playback logic ViewModel
///
struct VideoPlayerView: View {
    // MARK: - Properties

    /// @var videoFile
    /// @brief Video file to play
    /// @details VideoFile object containing video information.
    ///
    /// **Why use let:**
    ///
    /// Video file is set once when player is created and never changes:
    ///   - Guarantees immutability
    ///   - Clarifies intent
    ///   - To play a different video, create a new player
    ///
    let videoFile: VideoFile

    /// @var viewModel
    /// @brief Video player ViewModel
    /// @details ViewModel responsible for video playback logic.
    ///
    /// **What is @StateObject?**
    ///
    /// @StateObject is a property wrapper that creates and owns an ObservableObject.
    ///
    /// **@StateObject vs @ObservedObject:**
    ///
    /// ```
    /// @StateObject:
    ///   - View creates and owns the object
    ///   - Object persists even when View is recreated
    ///   - Manages object lifecycle
    ///
    /// @ObservedObject:
    ///   - Observes externally created object
    ///   - Object may be recreated when View is recreated
    ///   - Does not manage lifecycle
    /// ```
    ///
    /// **Why use @StateObject?**
    ///
    /// VideoPlayerViewModel must be created and managed by this View:
    ///   - Video playback state matches View lifecycle
    ///   - Playback should stop when View disappears
    ///   - Playback state persists when View re-renders
    ///
    /// **MVVM Pattern:**
    ///
    /// ```
    /// VideoPlayerView (View)
    ///       ↓ Forward user input
    /// VideoPlayerViewModel (ViewModel)
    ///       ↓ Execute business logic
    ///       ↓ Change @Published state
    ///       ↓
    /// VideoPlayerView auto re-renders
    /// ```
    ///
    @StateObject private var viewModel = VideoPlayerViewModel()

    /// Controls visibility state
    ///
    /// Stores whether playback controls are shown.
    ///
    /// **What is @State?**
    ///
    /// @State is a property wrapper that stores View internal state.
    ///
    /// **How it works:**
    /// ```
    /// Mouse hover
    ///     ↓
    /// showControls = true
    ///     ↓
    /// SwiftUI detects change
    ///     ↓
    /// View re-renders
    ///     ↓
    /// PlayerControlsView shown
    /// ```
    ///
    /// **Why default is true:**
    ///
    /// When player first opens:
    ///   - User needs to see controls
    ///   - Must be able to find play button
    ///   - Auto-hides after 3 seconds
    ///
    @State private var showControls = true

    /// Timer for auto-hiding controls
    ///
    /// Timer for automatically hiding controls.
    ///
    /// **What is Timer?**
    ///
    /// Optional<Timer> type:
    ///   - nil: No timer (e.g., paused state)
    ///   - Timer: Active timer
    ///
    /// **Timer operation flow:**
    ///
    /// ```
    /// 1. Mouse hover or control usage
    ///    ↓
    /// 2. Call resetControlsTimer()
    ///    ↓
    /// 3. Cancel existing timer (if any)
    ///    ↓
    /// 4. Create new timer (execute after 3 seconds)
    ///    ↓
    /// 5. 3 seconds elapsed
    ///    ↓
    /// 6. showControls = false (hide controls)
    /// ```
    ///
    /// **Why Optional?**
    ///
    /// Timer is not needed in all situations:
    ///   - When paused: Timer unnecessary (keep controls visible)
    ///   - When playing: Timer needed (hide after 3 seconds)
    ///
    @State private var controlsTimer: Timer?

    /// Fullscreen state
    ///
    /// Stores whether fullscreen mode is enabled.
    ///
    /// **Fullscreen mode:**
    ///
    /// false (normal mode):
    ///   - Window title bar present
    ///   - Menu bar displayed
    ///   - Resizable
    ///
    /// true (fullscreen mode):
    ///   - Occupies entire screen
    ///   - Title bar/menu bar hidden
    ///   - Immersive experience
    ///
    @State private var isFullscreen = false

    /// Keyboard event monitor
    ///
    /// Monitor for detecting keyboard events.
    ///
    /// **What is Any? type?**
    ///
    /// NSEvent.addLocalMonitorForEvents returns Any? type:
    ///   - Actually a special monitor object
    ///   - Needed when removing with removeMonitor()
    ///   - Type is unclear, so stored as Any
    ///
    /// **Keyboard monitoring:**
    ///
    /// ```
    /// 1. Call setupKeyboardMonitor()
    ///    ↓
    /// 2. Register NSEvent.addLocalMonitorForEvents
    ///    ↓
    /// 3. User inputs key
    ///    ↓
    /// 4. handleKeyEvent() auto-called
    ///    ↓
    /// 5. Execute action based on key code
    /// ```
    ///
    /// **Lifecycle management:**
    ///
    /// ```
    /// onAppear:
    ///   → setupKeyboardMonitor() (register monitor)
    ///
    /// onDisappear:
    ///   → removeKeyboardMonitor() (remove monitor)
    /// ```
    ///
    /// If monitor is not removed:
    ///   - Memory leak occurs
    ///   - Continues detecting key input even after player is closed
    ///   - App performance degradation
    ///
    @State private var keyMonitor: Any?

    // MARK: - Body

    var body: some View {
        // **Layout video and controls with VStack:**
        //
        // VStack(spacing: 0):
        //   - Arrange video area and controls area vertically
        //   - spacing: 0 → No gap, flush
        //
        // Layout:
        // ```
        // ┌─────────────────────┐
        // │                     │
        // │   Video Display     │ ← Variable size (maxHeight: .infinity)
        // │                     │
        // ├─────────────────────┤ ← Gap 0
        // │ [Player Controls]   │ ← Fixed height
        // └─────────────────────┘
        // ```
        //
        VStack(spacing: 0) {
            // MARK: Video Display Area

            // Video display area
            //
            // Area displaying video frames.
            //
            // videoDisplay is a computed property defined below.
            //
            videoDisplay
                // **.frame(maxWidth: .infinity, maxHeight: .infinity):**
                //
                // Set to occupy all available space.
                //
                // maxWidth: .infinity
                //   - Use entire parent width
                //   - Auto-adjust based on window size
                //
                // maxHeight: .infinity
                //   - Use entire parent height
                //   - Occupy all remaining space except controls
                //
                // Result:
                // ```
                // Small window:
                // ┌────────┐
                // │ Video  │
                // └────────┘
                //
                // Large window:
                // ┌────────────────────┐
                // │                    │
                // │       Video        │
                // │                    │
                // └────────────────────┘
                // ```
                //
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // **.background(Color.black):**
                //
                // Set background to black.
                //
                // Why use black background:
                //   ✓ Standard for video players (YouTube, Netflix, etc.)
                //   ✓ Surroundings are dark when video is smaller than screen
                //   ✓ Enhanced immersion
                //   ✓ Letterbox effect
                //
                // Letterbox example:
                // ```
                // ┌─────────────────────┐
                // │■■■■■■■■■■■■■■■■■■■■■│ ← Black margin
                // │┌───────────────────┐│
                // ││   16:9 Video      ││
                // │└───────────────────┘│
                // │■■■■■■■■■■■■■■■■■■■■■│ ← Black margin
                // └─────────────────────┘
                // ```
                //
                .background(Color.black)

                // **.onHover { isHovering in ... }:**
                //
                // Modifier that detects mouse hover state.
                //
                // **How it works:**
                //
                // ```
                // Mouse enters video area
                //     ↓
                // Call onHover closure (isHovering = true)
                //     ↓
                // showControls = true (show controls)
                //     ↓
                // resetControlsTimer() (start 3-second timer)
                // ```
                //
                // ```
                // Mouse leaves video area
                //     ↓
                // Call onHover closure (isHovering = false)
                //     ↓
                // Timer continues running...
                //     ↓
                // After 3 seconds showControls = false (hide controls)
                // ```
                //
                // **Why not hide controls immediately when isHovering is false?**
                //
                // Even if user moves mouse slightly:
                //   - Controls don't flicker
                //   - Smooth user experience
                //   - Delayed hiding via timer
                //
                .onHover { isHovering in
                    if isHovering {
                        // Show controls when mouse enters
                        showControls = true
                        // Reset timer (restart 3-second countdown)
                        resetControlsTimer()
                    }
                }

            // MARK: Player Controls

            // Controls (shown at bottom)
            //
            // Conditionally display playback controls.
            //
            // **Conditional rendering:**
            //
            // if showControls:
            //   - Render PlayerControlsView only when showControls is true
            //   - If false, entire block is not rendered
            //
            // **PlayerControlsView:**
            //
            // Separate View providing controls for play, pause, seek, volume, etc.
            //
            // Passing viewModel:
            //   - PlayerControlsView calls viewModel methods
            //   - e.g., viewModel.play(), viewModel.pause(), etc.
            //
            if showControls {
                PlayerControlsView(viewModel: viewModel)
                    // **.transition(.move(edge: .bottom)):**
                    //
                    // Define animation when controls appear and disappear.
                    //
                    // **.move(edge: .bottom):**
                    //   - Slide in from bottom to top
                    //   - Slide out from top to bottom
                    //
                    // Animation effect:
                    // ```
                    // Show controls (showControls = true):
                    // ┌─────────────────┐
                    // │     Video       │
                    // ├─────────────────┤
                    // │ [Controls] ↑    │ ← Slide up from bottom
                    // └─────────────────┘
                    //
                    // Hide controls (showControls = false):
                    // ┌─────────────────┐
                    // │     Video       │
                    // └─────────────────┘
                    //   [Controls] ↓      ← Slide down out
                    // ```
                    //
                    // **Why use animation?**
                    //
                    // ✓ Smooth transition
                    //   → Doesn't appear or disappear abruptly
                    //
                    // ✓ Visual feedback
                    //   → User perceives state change
                    //
                    // ✓ Professional feel
                    //   → Polished app experience
                    //
                    .transition(.move(edge: .bottom))
            }
        }
        // **.onAppear { ... }:**
        //
        // Closure executed when View appears on screen.
        //
        // **View lifecycle:**
        //
        // ```
        // 1. View creation
        //    ↓
        // 2. body rendering
        //    ↓
        // 3. onAppear execution ← Here
        //    ↓
        // 4. View being displayed...
        //    ↓
        // 5. onDisappear execution
        //    ↓
        // 6. View removal
        // ```
        //
        // **What this onAppear does:**
        //
        .onAppear {
            // 1. Load video
            //
            // viewModel.loadVideo(videoFile):
            //   - Pass VideoFile data to ViewModel
            //   - Initialize video decoder
            //   - Load first frame
            //
            viewModel.loadVideo(videoFile)

            // 2. Start controls timer
            //
            // resetControlsTimer():
            //   - Start auto-hide controls timer after 3 seconds
            //   - Give user time to see controls
            //
            resetControlsTimer()

            // 3. Setup keyboard monitor
            //
            // setupKeyboardMonitor():
            //   - Register NSEvent monitor
            //   - Enable keyboard shortcuts
            //   - Detect Space, arrows, F, ESC, etc.
            //
            setupKeyboardMonitor()
        }

        // **.onDisappear { ... }:**
        //
        // Closure executed when View disappears from screen.
        //
        // **Cleanup:**
        //
        // onDisappear is critical for resource cleanup.
        // Without cleanup:
        //   - Memory leaks
        //   - Continues running in background
        //   - App performance degradation
        //
        .onDisappear {
            // 1. Stop video playback
            //
            // viewModel.stop():
            //   - Stop video decoder
            //   - Release resources
            //   - Stop audio output
            //
            viewModel.stop()

            // 2. Invalidate timer
            //
            // controlsTimer?.invalidate():
            //   - Cancel timer
            //   - Release memory
            //   - ?. is Optional chaining (ignore if nil)
            //
            controlsTimer?.invalidate()

            // 3. Remove keyboard monitor
            //
            // removeKeyboardMonitor():
            //   - Deregister NSEvent monitor
            //   - Prevent memory leak
            //   - Don't interfere with other View's keyboard input
            //
            removeKeyboardMonitor()
        }
    }

    // MARK: - Video Display

    /// Video display area
    ///
    /// Area displaying video frames and state.
    ///
    /// **What is Computed Property?**
    ///
    /// ```swift
    /// private var videoDisplay: some View {
    ///     // Return View
    /// }
    /// ```
    ///
    /// Calculated and returned each time, not stored.
    ///
    /// **Why use Computed Property?**
    ///
    /// ✓ Keep body concise
    ///   → body doesn't become too long
    ///
    /// ✓ Reusable
    ///   → Can be called from multiple places (currently one)
    ///
    /// ✓ Improved readability
    ///   → Meaningful name: videoDisplay
    ///
    private var videoDisplay: some View {
        // **ZStack - Layer stacking:**
        //
        // ZStack stacks child Views along Z-axis (depth).
        //
        // Z-axis order (back → front):
        // ```
        // 1. Black background (default)
        //    ↓
        // 2. VideoFrameView (if frame exists)
        //    or ProgressView (if buffering)
        //    or Error View (if error occurred)
        //    or Placeholder (no video)
        // ```
        //
        // **Why use ZStack?**
        //
        // To display different Views at the same position based on state:
        //   - Frame display
        //   - Loading spinner
        //   - Error message
        //   - Placeholder
        //
        // All should be centered, so ZStack is appropriate.
        //
        ZStack {
            // **Conditional rendering based on state:**
            //
            // Display only one based on priority using if-else if-else chain.

            // Case 1: Video frame available
            //
            // Display video frame if available.
            //
            // **Optional Binding:**
            //
            // if let frame = viewModel.currentFrame:
            //   - viewModel.currentFrame is Optional<VideoFrame>
            //   - If not nil, store unwrapped value in frame variable
            //   - frame can be used within block
            //
            if let frame = viewModel.currentFrame {
                // **VideoFrameView:**
                //
                // Sub-View that converts VideoFrame to CGImage and displays on screen.
                //
                // Operation process:
                // ```
                // VideoFrame (pixel data)
                //     ↓
                // frame.toCGImage() (CGImage conversion)
                //     ↓
                // Image(cgImage) (SwiftUI Image)
                //     ↓
                // Render on screen
                // ```
                //
                VideoFrameView(frame: frame)

                // Case 2: Buffering
                //
                // Display loading spinner if buffering.
                //
                // viewModel.isBuffering:
                //   - Reading video data
                //   - Loading from network or disk
                //   - Preparing for decoding
                //
            } else if viewModel.isBuffering {
                // **ProgressView:**
                //
                // Standard loading indicator for macOS/iOS.
                //
                // ProgressView("Loading..."):
                //   - Spinning spinner + text
                //   - System default style
                //
                // Appearance on macOS:
                // ```
                //     ⟳
                //  Loading...
                // ```
                //
                ProgressView("Loading...")
                    // White text (to be visible on black background)
                    .foregroundColor(.white)

                // Case 3: Error
                //
                // Display error message if error occurred.
                //
                // **Optional Binding:**
                //
                // if let errorMessage = viewModel.errorMessage:
                //   - If errorMessage is not nil (error exists)
                //   - Store unwrapped string in errorMessage
                //   - Display error UI
                //
            } else if let errorMessage = viewModel.errorMessage {
                // **Error UI:**
                //
                // User-friendly error display:
                //   - Icon (warning triangle)
                //   - Title ("Error")
                //   - Detailed message (errorMessage)
                //
                VStack(spacing: 16) {
                    // **Warning icon:**
                    //
                    // exclamationmark.triangle.fill:
                    //   - Filled warning triangle
                    //   - Universal warning/error symbol
                    //
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))  // Large size for emphasis
                        .foregroundColor(.yellow)  // Yellow warning

                    // **Error title:**
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.bold)

                    // **Error detail message:**
                    //
                    // errorMessage examples:
                    //   - "Failed to load video file"
                    //   - "Unsupported codec"
                    //   - "File not found"
                    //
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)  // Secondary color
                        // **.multilineTextAlignment(.center):**
                        //
                        // Center-align multi-line text.
                        //
                        // Example:
                        // ```
                        // Failed to decode video.
                        //    Codec not supported.
                        // ```
                        //
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)  // All text white
                .padding()  // Add padding

                // Case 4: Placeholder
                //
                // Otherwise (no video) display placeholder.
                //
                // When does this case occur?
                //   - Video not yet loaded
                //   - Load completed but no frame
                //   - Initial state
                //
            } else {
                // **Placeholder UI:**
                //
                // Default UI indicating no video:
                //   - Video icon
                //   - "No video loaded" message
                //
                VStack(spacing: 16) {
                    // **Video icon:**
                    //
                    // video.fill:
                    //   - Filled video camera icon
                    //   - Common symbol representing "video"
                    //
                    Image(systemName: "video.fill")
                        .font(.system(size: 64))  // Very large size
                        .foregroundColor(.secondary)  // Light gray

                    Text("No video loaded")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Reset controls auto-hide timer
    ///
    /// Reset the controls auto-hide timer.
    ///
    /// **How it works:**
    ///
    /// 1. Cancel existing timer (if any)
    /// 2. Create new timer if playing
    /// 3. Hide controls after 3 seconds
    ///
    /// **When is it called?**
    ///
    /// - On mouse hover
    /// - When using controls (clicking play button, etc.)
    /// - When View appears
    ///
    private func resetControlsTimer() {
        // **Invalidate existing timer:**
        //
        // controlsTimer?.invalidate():
        //   - ?. is Optional chaining
        //   - Call invalidate() if not nil
        //   - Cancel timer and release memory
        //
        // Why cancel existing timer?
        //   - If user keeps moving mouse
        //   - Continuously reset 3-second countdown
        //   - Prevent multiple timers from being created
        //
        controlsTimer?.invalidate()

        // Auto-hide controls after 3 seconds of inactivity (only when playing)
        //
        // Start auto-hide timer only when playing.
        //
        // **Why hide only when playing?**
        //
        // When paused:
        //   - User needs to see controls
        //   - Selecting next action
        //   - Keep controls visible
        //
        // When playing:
        //   - Focus on watching video
        //   - Controls are distracting
        //   - Auto-hide after 3 seconds
        //
        if viewModel.playbackState == .playing {
            // **Timer.scheduledTimer:**
            //
            // Create a timer that executes after a certain time.
            //
            // Parameters:
            //   - withTimeInterval: 3.0 (3 seconds)
            //   - repeats: false (execute once only)
            //   - closure: { _ in ... } (code to execute)
            //
            controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                // **withAnimation:**
                //
                // Perform state change with animation.
                //
                // Without withAnimation:
                //   → showControls = false → Controls disappear immediately
                //
                // With withAnimation:
                //   → showControls = false → Controls slide out smoothly
                //
                // Works with .transition(.move(edge: .bottom)):
                //   → Slides down while disappearing
                //
                withAnimation {
                    showControls = false
                }
            }
        }
    }

    // MARK: - Keyboard Shortcuts

    /// Setup keyboard event monitor
    ///
    /// Set up keyboard event monitor.
    ///
    /// **What is NSEvent?**
    ///
    /// NSEvent is the event system of macOS AppKit.
    ///   - Keyboard input
    ///   - Mouse clicks
    ///   - Scrolling, etc.
    ///
    /// **Event Monitor:**
    ///
    /// Event monitor "listens" for specific events:
    ///   - Catch events across entire app
    ///   - Filter specific events only
    ///   - Forward or block events after processing
    ///
    private func setupKeyboardMonitor() {
        // **NSEvent.addLocalMonitorForEvents:**
        //
        // Register local event monitor.
        //
        // **Local vs Global monitor:**
        //
        // Local:
        //   - Detect events within current app only
        //   - Ignore key inputs from other apps
        //   - No permission required
        //
        // Global:
        //   - Detect events system-wide
        //   - Detect key inputs from other apps too
        //   - Accessibility permission required
        //
        // Parameters:
        //   - matching: .keyDown (when key is pressed)
        //   - handler: Event processing closure
        //
        // Return value:
        //   - Monitor object of Any? type
        //   - Used later to remove with removeMonitor()
        //
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // **[self] capture list:**
            //
            // Closure captures self.
            //
            // Normally we use [weak self], but:
            //   - Here we use [self] (strong reference)
            //   - Monitor persists while View is alive
            //   - Explicitly removed in onDisappear
            //
            // Memory management:
            // ```
            // View creation
            //   ↓
            // setupKeyboardMonitor() (register monitor)
            //   ↓
            // View alive (monitor active)
            //   ↓
            // View disappears (onDisappear)
            //   ↓
            // removeKeyboardMonitor() (remove monitor)
            // ```
            //
            // **handleKeyEvent(event):**
            //
            // Actual key handling logic is separated into another method.
            //
            // Return value:
            //   - NSEvent?: Processed event or nil
            //   - If nil returned, consume event (not forwarded elsewhere)
            //   - If event returned, continue forwarding event
            //
            handleKeyEvent(event)
        }
    }

    /// Remove keyboard event monitor
    ///
    /// Remove keyboard event monitor.
    ///
    /// **Why must monitor be removed?**
    ///
    /// If not removed:
    ///   - Memory leak occurs
    ///   - Continues detecting key input even after player closes
    ///   - Interferes with other View's keyboard actions
    ///   - App performance degradation
    ///
    /// **Lifecycle:**
    ///
    /// ```
    /// onAppear:
    ///   → Call setupKeyboardMonitor()
    ///
    /// onDisappear:
    ///   → Call removeKeyboardMonitor() ← Here
    /// ```
    ///
    private func removeKeyboardMonitor() {
        // **Optional Binding:**
        //
        // if let monitor = keyMonitor:
        //   - If keyMonitor is not nil
        //   - Store unwrapped value in monitor variable
        //   - Execute block
        //
        if let monitor = keyMonitor {
            // **NSEvent.removeMonitor:**
            //
            // Remove registered event monitor.
            //
            // Parameter:
            //   - monitor: Object returned from setupKeyboardMonitor()
            //
            NSEvent.removeMonitor(monitor)

            // **Set keyMonitor to nil:**
            //
            // Set to nil after removing monitor.
            //
            // Reasons:
            //   - Prevent removing already-removed monitor again
            //   - Accurately reflect Optional state
            //   - Confirm memory release
            //
            keyMonitor = nil
        }
    }

    /// Handle keyboard event
    ///
    /// Process keyboard event and execute appropriate action.
    ///
    /// **Parameters:**
    /// - event: NSEvent object (containing key info)
    ///
    /// **Return value:**
    /// - NSEvent?: Determine whether to continue forwarding event
    ///   - nil: Consume event (no longer forwarded)
    ///   - event: Continue forwarding event
    ///
    /// **Supported shortcuts:**
    ///
    /// | Key       | Function        | Action              |
    /// |-----------|-----------------|---------------------|
    /// | Space     | Play/Pause      | togglePlayPause()   |
    /// | ←         | 5 sec backward  | seekBySeconds(-5.0) |
    /// | →         | 5 sec forward   | seekBySeconds(5.0)  |
    /// | ↑         | Volume up       | adjustVolume(+0.1)  |
    /// | ↓         | Volume down     | adjustVolume(-0.1)  |
    /// | F         | Toggle fullscr. | toggleFullscreen()  |
    /// | ESC       | Exit fullscreen | toggleFullscreen()  |
    ///
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Get the key code
        //
        // **What is Key Code?**
        //
        // macOS assigns a unique number to each key:
        //   - 49: Space
        //   - 123: Left arrow (←)
        //   - 124: Right arrow (→)
        //   - 126: Up arrow (↑)
        //   - 125: Down arrow (↓)
        //   - 3: F key
        //   - 53: ESC
        //
        // **Why use numbers instead of characters?**
        //
        // Key code represents physical key position:
        //   - Independent of keyboard layout
        //   - Unrelated to input source like English, Korean, etc.
        //   - Can handle special keys like arrows, Space, etc.
        //
        let keyCode = event.keyCode

        // **Handle each key with switch:**
        //
        // Execute different action for each key code.
        //
        switch keyCode {
        case 49: // Space
            // **Toggle play/pause:**
            //
            // Space handles play/pause in most video players:
            //   - YouTube
            //   - VLC
            //   - QuickTime
            //   - Netflix
            //
            viewModel.togglePlayPause()
            // **return nil:**
            //
            // Consume the event.
            //
            // If nil is returned:
            //   - Space key is not forwarded elsewhere
            //   - e.g., Prevent space input in text field
            //
            return nil

        case 123: // Left arrow
            // **Seek backward 5 seconds:**
            //
            // seekBySeconds(-5.0):
            //   - 5 seconds backward from current playback position
            //   - Negative value = backward
            //
            // Why 5 seconds:
            //   - Not too short (meaningful seek)
            //   - Not too long (precise seeking possible)
            //   - Industry standard (YouTube, etc.)
            //
            viewModel.seekBySeconds(-5.0)
            return nil

        case 124: // Right arrow
            // **Seek forward 5 seconds:**
            //
            // seekBySeconds(5.0):
            //   - 5 seconds forward from current playback position
            //   - Positive value = forward
            //
            viewModel.seekBySeconds(5.0)
            return nil

        case 126: // Up arrow
            // **Increase volume:**
            //
            // adjustVolume(by: 0.1):
            //   - Increase volume by 0.1 (10%)
            //   - 0.0 (mute) ~ 1.0 (max)
            //
            // Why adjust by 10%:
            //   - Fine control possible
            //   - 10 presses to reach max/min
            //   - User-friendly
            //
            viewModel.adjustVolume(by: 0.1)
            return nil

        case 125: // Down arrow
            // **Decrease volume:**
            //
            // adjustVolume(by: -0.1):
            //   - Decrease volume by 0.1 (10%)
            //   - Negative value = decrease
            //
            viewModel.adjustVolume(by: -0.1)
            return nil

        case 3: // F key
            // **Toggle fullscreen:**
            //
            // F key is used as fullscreen shortcut in many video players:
            //   - YouTube: F
            //   - VLC: F
            //   - QuickTime: Cmd+Ctrl+F (but F is also supported)
            //
            toggleFullscreen()
            return nil

        case 53: // ESC
            // **Exit fullscreen:**
            //
            // ESC generally means "exit" or "cancel".
            //
            // Conditional handling:
            //   - Handle only when in fullscreen mode
            //   - Forward event in normal mode (can be used for other purposes)
            //
            if isFullscreen {
                toggleFullscreen()
                return nil  // Consume event
            }
        // **Allow ESC to be used for other purposes besides exiting fullscreen:**
        //
        // If not fullscreen, continue forwarding event.
        // e.g., Used to close Sheet or Alert

        default:
            // **Unhandled keys:**
            //
            // All keys not matching above cases come here.
            //
            // break:
            //   - Do nothing
            //   - Proceed to next code (return event)
            //
            break
        }

        // **Continue forwarding event:**
        //
        // return event:
        //   - Forward unhandled event to next handler
        //   - e.g., Text input, other shortcuts, etc.
        //
        return event
    }

    // MARK: - Fullscreen

    /// Toggle fullscreen mode
    ///
    /// Toggle fullscreen mode.
    ///
    /// **What is fullscreen mode?**
    ///
    /// Normal mode:
    ///   - Window title bar present
    ///   - Menu bar displayed
    ///   - Dock displayed
    ///   - Resizable
    ///
    /// Fullscreen mode:
    ///   - Occupies entire screen
    ///   - Title bar/menu bar hidden
    ///   - Dock auto-hidden
    ///   - Immersive experience
    ///
    private func toggleFullscreen() {
        // **NSApplication.shared.keyWindow:**
        //
        // Get currently active window.
        //
        // NSApplication.shared:
        //   - App's singleton instance
        //   - Manages entire app state
        //
        // keyWindow:
        //   - Window currently receiving keyboard input
        //   - Typically the window user is viewing
        //
        // **guard let ... else { return }:**
        //
        // Safely unwrap with Optional Binding:
        //   - If window is nil (no window), return
        //   - If not nil, continue
        //
        guard let window = NSApplication.shared.keyWindow else { return }

        // **Toggle state:**
        //
        // isFullscreen.toggle():
        //   - true → false
        //   - false → true
        //
        // Why toggle state first:
        //   - Correct behavior on next toggle call
        //   - UI state synchronization
        //
        isFullscreen.toggle()

        // **Fullscreen transition:**
        //
        if isFullscreen {
            // **Enter fullscreen mode:**
            //
            // window.toggleFullScreen(nil):
            //   - nil: sender parameter (not used)
            //   - Transition window to fullscreen
            //   - Smooth transition with animation
            //
            // Effect:
            // ```
            // Normal window
            //     ↓
            // Expand to full screen
            //     ↓
            // Hide title bar/menu bar
            //     ↓
            // Fullscreen mode
            // ```
            //
            window.toggleFullScreen(nil)
        } else {
            // **Return to normal mode:**
            //
            // Check if already fullscreen:
            //   - window.styleMask.contains(.fullScreen)
            //   - Check .fullScreen flag
            //
            // Why check?
            //   - Prevent duplicate toggleFullScreen() call
            //   - Prevent animation conflicts
            //   - Safe state management
            //
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
}

// MARK: - Video Frame View

/// @struct VideoFrameView
/// @brief Individual video frame display View
/// @details Converts VideoFrame to CGImage and displays on screen.
///
/// **Responsibilities:**
/// - VideoFrame (pixel data) → CGImage conversion
/// - CGImage → SwiftUI Image display
/// - Adjust to screen size
///
/// **Usage example:**
/// ```swift
/// if let frame = viewModel.currentFrame {
///     VideoFrameView(frame: frame)
/// }
/// ```
///
struct VideoFrameView: View {
    // MARK: - Properties

    /// @var frame
    /// @brief Video frame data
    /// @details VideoFrame object to display.
    ///
    /// **What is VideoFrame?**
    ///
    /// VideoFrame represents one frame of video:
    /// ```swift
    /// struct VideoFrame {
    ///     let pixelBuffer: CVPixelBuffer  // Pixel data
    ///     let timestamp: CMTime           // Time information
    ///     let width: Int                  // Width
    ///     let height: Int                 // Height
    ///
    ///     func toCGImage() -> CGImage? {
    ///         // CVPixelBuffer → CGImage conversion
    ///     }
    /// }
    /// ```
    ///
    let frame: VideoFrame

    // MARK: - Body

    var body: some View {
        // **GeometryReader:**
        //
        // GeometryReader measures the size of space allocated from parent.
        //
        // **Why is it needed?**
        //
        // To display video frame fitted to screen:
        //   - Need to know current screen (parent View) size
        //   - Maintain frame's aspect ratio
        //   - Adjust according to screen size
        //
        // **How it works:**
        //
        // ```
        // GeometryReader { geometry in
        //     // geometry.size.width
        //     // geometry.size.height
        //     // Space allocated from parent
        // }
        // ```
        //
        // **Closure parameter:**
        //
        // geometry: GeometryProxy
        //   - .size: Size provided by parent (CGSize)
        //   - .frame(in:): Position within coordinate system
        //   - .safeAreaInsets: Safe area information
        //
        GeometryReader { geometry in
            // **Optional Binding:**
            //
            // if let cgImage = frame.toCGImage():
            //   - Attempt to convert VideoFrame to CGImage
            //   - If successful, store in cgImage
            //   - If failed (nil), execute else block
            //
            // **Conversion failure reasons:**
            //   - Pixel buffer format mismatch
            //   - Out of memory
            //   - Corrupted frame data
            //
            if let cgImage = frame.toCGImage() {
                // **Image(decorative:scale:):**
                //
                // Convert CGImage to SwiftUI Image.
                //
                // **What is decorative?**
                //
                // Image(decorative: cgImage, scale: 1.0):
                //   - decorative: No accessibility label
                //   - VoiceOver doesn't read it as "image"
                //   - Considered decorative image
                //
                // Why use decorative?
                //   - Video frames change rapidly and continuously
                //   - VoiceOver reading each frame would be confusing
                //   - Unnecessary information from accessibility perspective
                //
                // scale: 1.0:
                //   - Image scale (Retina display, etc.)
                //   - 1.0 = 1:1 pixel mapping
                //   - 2.0 = @2x (Retina)
                //
                Image(decorative: cgImage, scale: 1.0)
                    // **.resizable():**
                    //
                    // Make image resizable.
                    //
                    // Without resizable():
                    //   - Image displayed at original size
                    //   - May be larger or smaller than screen
                    //   - Size cannot be adjusted
                    //
                    // With resizable():
                    //   - Size adjustable with .frame() modifier
                    //   - Ratio maintainable with aspectRatio()
                    //   - Can be fitted to screen
                    //
                    .resizable()

                    // **.aspectRatio(contentMode:):**
                    //
                    // Adjust size while maintaining image aspect ratio.
                    //
                    // **contentMode: .fit:**
                    //
                    // .fit:
                    //   - Adjust to show entire image
                    //   - May have margins on one side (letterbox)
                    //   - No image cropping
                    //
                    // .fill:
                    //   - Fill entire space
                    //   - Image may be cropped
                    //   - No margins
                    //
                    // Example:
                    // ```
                    // Display 16:9 video on 4:3 screen
                    //
                    // .fit:
                    // ┌─────────────────┐
                    // │■■■■■■■■■■■■■■■■■│ ← Black margin
                    // │┌───────────────┐│
                    // ││   16:9 Video  ││
                    // │└───────────────┘│
                    // │■■■■■■■■■■■■■■■■■│ ← Black margin
                    // └─────────────────┘
                    //
                    // .fill:
                    // ┌─────────────────┐
                    // ││   16:9 Video  ││ ← Left/right cropped
                    // └─────────────────┘
                    // ```
                    //
                    .aspectRatio(contentMode: .fit)

                    // **.frame(width:height:):**
                    //
                    // Set image to specific size.
                    //
                    // geometry.size.width:
                    //   - Width provided by parent (GeometryReader)
                    //   - Changes according to screen or window size
                    //
                    // geometry.size.height:
                    //   - Height provided by parent
                    //
                    // Effect of this combination:
                    // ```
                    // resizable() + aspectRatio(.fit) + frame(geometry.size)
                    //     ↓
                    // Video adjusted to screen size
                    //     ↓
                    // while maintaining aspect ratio
                    // ```
                    //
                    .frame(width: geometry.size.width, height: geometry.size.height)

            } else {
                // **If CGImage conversion fails:**
                //
                // Display black screen.
                //
                // Why show black screen:
                //   - Don't explicitly display error (frame-level failures are common)
                //   - Player attempts next frame
                //   - May be temporary issue
                //   - Minimize user experience disruption
                //
                Color.black
            }
        }
    }
}

// MARK: - Preview

// Preview temporarily disabled - requires sample data
//
// **Why preview is disabled:**
//
// VideoPlayerView requires actual VideoFile data:
//   - Video decoder initialization
//   - AVFoundation resources
//   - Actual video file path
//
// In Xcode preview:
//   - Sample data preparation is complex
//   - Resource access limitations
//   - Performance issues
//
// **To enable preview:**
//
// 1. Prepare sample VideoFile
// 2. Include simple test video file
// 3. Use Mock VideoPlayerViewModel
//
// Example:
// ```swift
// struct VideoPlayerView_Previews: PreviewProvider {
//     static var previews: some View {
//         VideoPlayerView(videoFile: .testVideo)
//             .frame(width: 800, height: 600)
//     }
// }
// ```
//
// struct VideoPlayerView_Previews: PreviewProvider {
//     static var previews: some View {
//         VideoPlayerView(videoFile: sampleVideoFile)
//             .frame(width: 800, height: 600)
//     }
// }
