/// @file PlayerControlsView.swift
/// @brief Video player playback control UI
/// @author BlackboxPlayer Development Team
/// @details
/// View providing video player playback controls. Includes timeline slider, play/pause,
/// frame-by-frame navigation, time display, speed control, and volume control features.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// @struct PlayerControlsView
/// @brief View providing video player playback controls
///
/// @details
/// View providing video player playback controls.
///
/// ## Feature Overview
/// ```
/// ┌──────────────────────────────────────────────────────┐
/// │  [========●================]  (Timeline Slider)       │
/// │                                                       │
/// │  ▶  ⏮  ⏭     00:05 / 01:30    🏎 1.0x   🔊 ━━━━━    │
/// │  Play Frame    Time Display    Speed    Volume       │
/// └──────────────────────────────────────────────────────┘
/// ```
///
/// ## Main Components
/// - **Timeline Slider**: Time navigation bar implemented with custom drag gesture
/// - **Playback Controls**: Play/pause, frame-by-frame navigation buttons
/// - **Time Display**: Current time / Total time (monospaced font)
/// - **Speed Control**: Playback speed selection via Menu component (0.5x ~ 2.0x)
/// - **Volume Control**: Volume adjustment via Slider component (0 ~ 1)
///
/// ## SwiftUI Core Concepts
///
/// ### 1. @ObservedObject vs @State Role Separation
/// ```swift
/// @ObservedObject var viewModel: VideoPlayerViewModel  // External data source
/// @State private var isSeeking: Bool = false           // Internal UI state
/// ```
///
/// **@ObservedObject (External State):**
/// - Video playback state managed by ViewModel
/// - Examples: playbackState, playbackPosition, volume
/// - Shared with other Views
///
/// **@State (Internal State):**
/// - Temporary UI state used only in this View
/// - Examples: isSeeking (whether dragging), seekPosition (drag position)
/// - Not shared with other Views
///
/// ### 2. Dynamic Size Calculation with GeometryReader
/// ```swift
/// GeometryReader { geometry in
///     // Calculate slider size using geometry.size.width
///     let thumbX = geometry.size.width * playbackPosition - 8
/// }
/// ```
///
/// **What is GeometryReader?**
/// - Container that provides parent View's size and position information
/// - Enables child Views to calculate size dynamically
/// - Essential for UI like timeline sliders that change length based on screen size
///
/// ### 3. Custom Slider Implementation with DragGesture
/// ```swift
/// .gesture(
///     DragGesture(minimumDistance: 0)
///         .onChanged { value in
///             // During drag: Update temporary position
///             isSeeking = true
///             seekPosition = value.location.x / geometry.size.width
///         }
///         .onEnded { _ in
///             // End of drag: Pass final position to ViewModel
///             viewModel.seek(to: seekPosition)
///             isSeeking = false
///         }
/// )
/// ```
///
/// **How DragGesture Works:**
/// 1. **onChanged**: Called continuously during drag (every finger/mouse movement)
/// 2. **onEnded**: Called once when drag ends (when finger/mouse is released)
/// 3. **minimumDistance: 0**: Recognizes taps as drags (allows position change via click)
///
/// **Why is isSeeking state necessary?**
/// - During drag: Display seekPosition
/// - When not dragging: Display viewModel.playbackPosition
/// - This ensures smooth UI movement even during dragging
///
/// ### 4. Binding(get:set:) Customization
/// ```swift
/// Slider(value: Binding(
///     get: { viewModel.volume },           // Read value
///     set: { viewModel.setVolume($0) }     // Write value
/// ), in: 0...1)
/// ```
///
/// **What is Binding?**
/// - Property Wrapper that provides two-way data binding
/// - Allows Slider, TextField, etc. to read and write values
///
/// **Why use Binding(get:set:)?**
/// - Simple @State: Direct binding with `$volume`
/// - To call ViewModel methods: Use `Binding(get:set:)`
/// - This allows executing additional logic on value change (e.g., setting audio volume)
///
/// ### 5. Dropdown Menu Implementation with Menu Component
/// ```swift
/// Menu {
///     ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
///         Button(action: { viewModel.setPlaybackSpeed(speed) }) {
///             HStack {
///                 Text("\(speed)x")
///                 if speed == currentSpeed { Image(systemName: "checkmark") }
///             }
///         }
///     }
/// } label: {
///     Text("1.0x")
/// }
/// ```
///
/// **Menu Component Structure:**
/// 1. **Menu { ... }**: Define menu items
/// 2. **label: { ... }**: Button UI that opens the menu
/// 3. **ForEach**: Dynamically generate menu items by iterating through array
///
/// **What is id: \.self?**
/// - ForEach requires an ID to distinguish each item
/// - `id: \.self` uses the value itself as ID (0.5, 0.75, 1.0, etc.)
/// - Can be used with Hashable types like Double, String, etc.
///
/// ### 6. Dynamic Icons with Computed Properties
/// ```swift
/// private var playPauseIcon: String {
///     switch viewModel.playbackState {
///     case .stopped, .paused: return "play.fill"
///     case .playing: return "pause.fill"
///     }
/// }
///
/// private var volumeIcon: String {
///     if volume == 0 { return "speaker.slash.fill" }
///     else if volume < 0.33 { return "speaker.wave.1.fill" }
///     else if volume < 0.67 { return "speaker.wave.2.fill" }
///     else { return "speaker.wave.3.fill" }
/// }
/// ```
///
/// **What are Computed Properties?**
/// - Properties that are calculated and returned without storage
/// - Automatically recalculated when other properties (viewModel.playbackState) change
/// - Called every time the View's body is redrawn
///
/// **Why use Computed Property instead of function?**
/// - Function: `playPauseIcon()` - Requires parentheses on each call
/// - Computed Property: `playPauseIcon` - Used like a property (more natural)
///
/// ## Usage Examples
///
/// ### Example 1: Usage in VideoPlayerView
/// ```swift
/// struct VideoPlayerView: View {
///     @StateObject private var viewModel = VideoPlayerViewModel()
///
///     var body: some View {
///         VStack {
///             // Video display
///             VideoFrameView(frame: viewModel.currentFrame)
///
///             // Control UI
///             PlayerControlsView(viewModel: viewModel)
///         }
///     }
/// }
/// ```
///
/// ### Example 2: Multiple Players in MultiChannelPlayerView
/// ```swift
/// struct MultiChannelPlayerView: View {
///     @StateObject private var frontViewModel = VideoPlayerViewModel()
///     @StateObject private var rearViewModel = VideoPlayerViewModel()
///
///     var body: some View {
///         VStack {
///             HStack {
///                 VideoFrameView(frame: frontViewModel.currentFrame)
///                 VideoFrameView(frame: rearViewModel.currentFrame)
///             }
///
///             // Front camera controls
///             PlayerControlsView(viewModel: frontViewModel)
///
///             // Rear camera controls
///             PlayerControlsView(viewModel: rearViewModel)
///         }
///     }
/// }
/// ```
///
/// ## Practical Applications
///
/// ### Improving Timeline Slider Precision
/// ```swift
/// // Current: Pixel-based movement (may be imprecise)
/// let position = value.location.x / geometry.size.width
///
/// // Improved: Snap to frame boundaries
/// let totalFrames = viewModel.totalFrames
/// let framePosition = round(position * Double(totalFrames)) / Double(totalFrames)
/// seekPosition = framePosition
/// ```
///
/// ### Keyboard Shortcut Support
/// ```swift
/// .onKeyPress(.space) {
///     viewModel.togglePlayPause()
///     return .handled
/// }
/// .onKeyPress(.leftArrow) {
///     viewModel.stepBackward()
///     return .handled
/// }
/// ```
///
/// ### Quick Seek with Double Tap (Mobile)
/// ```swift
/// .gesture(
///     TapGesture(count: 2)
///         .onEnded { _ in
///             viewModel.seekBySeconds(10.0)  // 10 seconds forward
///         }
/// )
/// ```
///
/// ## Performance Optimization
///
/// ### 1. Minimize ViewModel Updates During Drag
/// ```swift
/// // Bad: Continuously update ViewModel during drag (performance degradation)
/// .onChanged { value in
///     viewModel.seek(to: value.location.x / width)  // ❌ Called too frequently
/// }
///
/// // Good: Update only local state during drag
/// .onChanged { value in
///     isSeeking = true
///     seekPosition = value.location.x / width  // ✅ Update UI only
/// }
/// .onEnded { _ in
///     viewModel.seek(to: seekPosition)  // ✅ Update ViewModel only at end
/// }
/// ```
///
/// ### 2. Prevent Time Display Flickering with Monospaced Font
/// ```swift
/// Text(viewModel.currentTimeString)
///     .font(.system(.body, design: .monospaced))
///     // ✅ monospaced: All digits have same width → Layout unchanged when time changes
///     // ❌ Regular font: "1" and "0" have different widths → UI shifts when time changes
/// ```
///
/// ## Test Data
///
/// ### Create Mock VideoPlayerViewModel
/// ```swift
/// extension VideoPlayerViewModel {
///     static func mock() -> VideoPlayerViewModel {
///         let vm = VideoPlayerViewModel()
///         vm.playbackState = .paused
///         vm.playbackPosition = 0.3  // 30% played
///         vm.currentTimeString = "00:18"
///         vm.durationString = "01:00"
///         vm.playbackSpeed = 1.0
///         vm.volume = 0.7
///         return vm
///     }
/// }
/// ```
///
/// ### Enable Preview
/// ```swift
/// struct PlayerControlsView_Previews: PreviewProvider {
///     static var previews: some View {
///         VStack {
///             // Playing state
///             PlayerControlsView(viewModel: {
///                 let vm = VideoPlayerViewModel.mock()
///                 vm.playbackState = .playing
///                 return vm
///             }())
///             .previewDisplayName("Playing")
///
///             // Paused state
///             PlayerControlsView(viewModel: {
///                 let vm = VideoPlayerViewModel.mock()
///                 vm.playbackState = .paused
///                 return vm
///             }())
///             .previewDisplayName("Paused")
///
///             // Muted state
///             PlayerControlsView(viewModel: {
///                 let vm = VideoPlayerViewModel.mock()
///                 vm.volume = 0
///                 return vm
///             }())
///             .previewDisplayName("Muted")
///         }
///         .frame(height: 100)
///         .padding()
///     }
/// }
/// ```
///
struct PlayerControlsView: View {
    // MARK: - Properties

    /// @var viewModel
    /// @brief ViewModel reference (@ObservedObject)
    ///
    /// **What is @ObservedObject?**
    /// - Property Wrapper that observes ObservableObject received from outside
    /// - Automatically updates View when ViewModel's @Published properties change
    /// - Parent View manages ViewModel's lifecycle
    ///
    /// **Difference from @StateObject:**
    /// ```
    /// @StateObject  → This View creates and owns ViewModel
    /// @ObservedObject → Uses ViewModel received from parent View
    /// ```
    ///
    /// **Example:**
    /// ```swift
    /// // Parent View
    /// struct VideoPlayerView: View {
    ///     @StateObject private var viewModel = VideoPlayerViewModel()  // Create
    ///
    ///     var body: some View {
    ///         PlayerControlsView(viewModel: viewModel)  // Pass
    ///     }
    /// }
    ///
    /// // Child View
    /// struct PlayerControlsView: View {
    ///     @ObservedObject var viewModel: VideoPlayerViewModel  // Receive
    /// }
    /// ```
    @ObservedObject var viewModel: VideoPlayerViewModel

    /// @var eventMarkers
    /// @brief Event marker array
    ///
    /// @details
    /// Event markers to be displayed on the timeline.
    /// Shows events such as rapid acceleration, hard braking, sharp turns detected from GPS data analysis.
    var eventMarkers: [EventMarker] = []

    /// @var isSeeking
    /// @brief Whether seeking is in progress (@State)
    ///
    /// **When does it become true?**
    /// - While user is dragging the timeline slider
    ///
    /// **When does it become false?**
    /// - When drag ends (onEnded)
    ///
    /// **Why is it necessary?**
    /// - During drag: Display seekPosition value
    /// - When not dragging: Display viewModel.playbackPosition value
    /// - This separation ensures smooth UI movement even during dragging
    ///
    /// **Example Scenario:**
    /// ```
    /// 1. During playback (isSeeking = false)
    ///    → Slider position = viewModel.playbackPosition (auto-incrementing)
    ///
    /// 2. User starts dragging (isSeeking = true)
    ///    → Slider position = seekPosition (drag position)
    ///    → viewModel.playbackPosition is ignored
    ///
    /// 3. Drag ends (isSeeking = false)
    ///    → viewModel.seek(to: seekPosition) called
    ///    → Display viewModel.playbackPosition value again
    /// ```
    @State private var isSeeking: Bool = false

    /// @var seekPosition
    /// @brief Seeking position (0.0 ~ 1.0) (@State)
    ///
    /// **Value Range:**
    /// - 0.0: Video start (0%)
    /// - 0.5: Video middle (50%)
    /// - 1.0: Video end (100%)
    ///
    /// **When is it updated?**
    /// - Calculated in DragGesture's onChanged based on drag position
    /// - Formula: `seekPosition = dragX / sliderWidth`
    ///
    /// **Why Double type?**
    /// - Double is more precise than CGFloat (better for video time calculations)
    /// - ViewModel's seek(to:) method also accepts Double
    ///
    /// **Calculation Example:**
    /// ```swift
    /// // Slider width: 400px
    /// // Drag position: 120px
    /// seekPosition = 120.0 / 400.0 = 0.3  // 30% position
    ///
    /// // Video duration: 60 seconds
    /// seekTime = 0.3 * 60 = 18 seconds
    /// ```
    @State private var seekPosition: Double = 0.0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Timeline slider
            //
            // Time navigation bar implemented with custom drag gesture.
            // Uses GeometryReader to calculate slider width dynamically.
            timelineSlider

            HStack(spacing: 20) {
                // Play/pause button
                //
                // Calls togglePlayPause()
                // Icon changes based on playbackState
                playPauseButton

                // Frame step buttons
                //
                // Calls stepBackward(), stepForward()
                // Useful for precise frame analysis
                frameStepButtons

                // Event navigation buttons
                //
                // Navigate to previous/next event
                // Immediately jump to events like rapid acceleration, hard braking, sharp turns
                if !eventMarkers.isEmpty {
                    eventNavigationButtons
                }

                // Segment selection buttons
                //
                // Set In/Out Point and extract
                segmentSelectionButtons

                // Snapshot button
                //
                // Save current frame as image
                snapshotButton

                // Share button
                //
                // Share video file, snapshot, segment
                shareButton

                Spacer()

                // Time display
                //
                // Format: "00:18 / 01:00"
                // Monospaced font prevents flickering
                timeDisplay

                Spacer()

                // Playback speed control
                //
                // Select 0.5x ~ 2.0x via Menu component
                // Checkmark shows current speed
                speedControl

                // Volume control
                //
                // 0 ~ 1 range via Slider component
                // Customized with Binding(get:set:)
                volumeControl
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
        // ✅ opacity(0.95): Slightly transparent → Video shows through slightly (macOS style)
    }

    // MARK: - Timeline Slider

    /// @brief Timeline slider
    ///
    /// ## Structure
    /// ```
    /// ┌──────────────────────────────────────┐
    /// │  [==========●==================]     │
    /// │   ^Played     ^Thumb   ^Total track  │
    /// └──────────────────────────────────────┘
    /// ```
    ///
    /// ## Layer Structure (bottom to top)
    /// 1. **Track Background**: Gray background (total length)
    /// 2. **Played Portion**: Blue bar (played portion)
    /// 3. **Thumb**: White circle (current position indicator)
    ///
    /// ## DragGesture Operation
    ///
    /// ### 1. onChanged (during drag)
    /// ```swift
    /// .onChanged { value in
    ///     isSeeking = true
    ///     let x = value.location.x              // Drag X coordinate
    ///     let width = geometry.size.width       // Slider width
    ///     seekPosition = max(0, min(1, x / width))  // Constrain to 0~1 range
    /// }
    /// ```
    ///
    /// **Calculation Process:**
    /// ```
    /// Slider width: 400px
    /// Drag X: 120px
    /// → seekPosition = 120 / 400 = 0.3 (30%)
    ///
    /// Drag X: -50px (outside left of slider)
    /// → seekPosition = max(0, -50 / 400) = 0.0 (0%)
    ///
    /// Drag X: 500px (outside right of slider)
    /// → seekPosition = min(1, 500 / 400) = 1.0 (100%)
    /// ```
    ///
    /// ### 2. onEnded (end of drag)
    /// ```swift
    /// .onEnded { _ in
    ///     viewModel.seek(to: seekPosition)  // Pass final position to ViewModel
    ///     isSeeking = false
    /// }
    /// ```
    ///
    /// ## Meaning of minimumDistance: 0
    /// ```swift
    /// DragGesture(minimumDistance: 0)
    /// ```
    ///
    /// - **0**: Recognizes taps as drags (immediate movement with click)
    /// - **Default (10)**: Must drag at least 10px to recognize
    ///
    /// **User Experience:**
    /// ```
    /// minimumDistance: 0  → Move to position with just a click (YouTube style)
    /// minimumDistance: 10 → Must drag to move (prevents accidental moves)
    /// ```
    ///
    /// ## Thumb Position Calculation
    /// ```swift
    /// .offset(x: geometry.size.width * (isSeeking ? seekPosition : viewModel.playbackPosition) - 8)
    /// ```
    ///
    /// **Why subtract 8?**
    /// - Thumb width is 16px
    /// - Subtract half (8px) to center align
    ///
    /// **Calculation Example:**
    /// ```
    /// Slider width: 400px
    /// playbackPosition: 0.3 (30%)
    /// Thumb center X = 400 * 0.3 = 120px
    /// Thumb left X = 120 - 8 = 112px (center aligned)
    /// ```
    private var timelineSlider: some View {
        VStack(spacing: 4) {
            /// Custom slider with frame markers
            ///
            /// Uses GeometryReader to get parent View's width.
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background (gray background)
                    //
                    // Gray bar representing total video length.
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    // Played portion (blue bar)
                    //
                    // Displays played portion in blue.
                    //
                    // **Width calculation:**
                    // - During drag: geometry.size.width * seekPosition
                    // - Normal playback: geometry.size.width * viewModel.playbackPosition
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width * (isSeeking ? seekPosition : viewModel.playbackPosition),
                            height: 4
                        )
                        .cornerRadius(2)

                    // Selected segment highlight (semi-transparent green bar)
                    //
                    // Visually displays segment between In Point ~ Out Point.
                    if let inTime = viewModel.inPoint, let outTime = viewModel.outPoint, viewModel.duration > 0 {
                        segmentHighlightView(inTime: inTime, outTime: outTime, width: geometry.size.width)
                    }

                    // Event markers (color-coded circles)
                    //
                    // Display events like rapid acceleration, hard braking, sharp turns on timeline.
                    // Only displayed when duration > 0 (video loaded)
                    if viewModel.duration > 0 {
                        ForEach(eventMarkers) { marker in
                            eventMarkerView(marker: marker, width: geometry.size.width)
                        }
                    }

                    // In Point marker (green triangle)
                    if let inTime = viewModel.inPoint, viewModel.duration > 0 {
                        inPointMarkerView(inTime: inTime, width: geometry.size.width)
                    }

                    // Out Point marker (green triangle)
                    if let outTime = viewModel.outPoint, viewModel.duration > 0 {
                        outPointMarkerView(outTime: outTime, width: geometry.size.width)
                    }

                    // Thumb (white circle)
                    //
                    // Circular indicator showing current playback position.
                    //
                    // **Position calculation:**
                    // 1. Base X = width * position
                    // 2. Center align = X - (thumbWidth / 2) = X - 8
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(
                            x: geometry.size.width * (isSeeking ? seekPosition : viewModel.playbackPosition) - 8
                        )
                }
                .gesture(
                    /// Implement slider drag with DragGesture
                    ///
                    /// **Effect of minimumDistance: 0:**
                    /// - Immediate movement with just a tap
                    /// - Time seeking possible with click alone, no drag needed
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            /// Called during drag (every finger/mouse movement)
                            ///
                            /// **Operation:**
                            /// 1. isSeeking = true (activate drag mode)
                            /// 2. Calculate seekPosition (constrain to 0~1 range)
                            isSeeking = true
                            let position = max(0, min(1, value.location.x / geometry.size.width))
                            seekPosition = position
                        }
                        .onEnded { _ in
                            /// Called when drag ends (when finger/mouse is released)
                            ///
                            /// **Operation:**
                            /// 1. Pass final position to ViewModel
                            /// 2. isSeeking = false (return to normal mode)
                            viewModel.seek(to: seekPosition)
                            isSeeking = false
                        }
                )
            }
            .frame(height: 16)
            .padding(.horizontal)
        }
    }

    // MARK: - Play/Pause Button

    /// @brief Play/pause button
    ///
    /// ## Operation
    /// - On click: Calls `viewModel.togglePlayPause()`
    /// - Icon: Determined by `playPauseIcon` computed property
    ///
    /// ## Icons by State
    /// ```
    /// .stopped, .paused → "play.fill"  (▶ play icon)
    /// .playing         → "pause.fill" (❚❚ pause icon)
    /// ```
    ///
    /// ## Effect of .buttonStyle(.plain)
    /// ```swift
    /// // Default button style
    /// Button { } → Blue background, white text
    ///
    /// // .plain style
    /// Button { }.buttonStyle(.plain) → No background, icon only
    /// ```
    ///
    /// ## .help() modifier
    /// ```swift
    /// .help("Pause")  // Display tooltip on mouse hover
    /// ```
    ///
    /// **macOS only:**
    /// - Works only on macOS (ignored on iOS)
    /// - Also helps with Accessibility
    private var playPauseButton: some View {
        Button(action: {
            viewModel.togglePlayPause()
        }) {
            Image(systemName: playPauseIcon)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .help(viewModel.playbackState == .playing ? "Pause" : "Play")
    }

    /// @brief Play/pause icon (Computed Property)
    ///
    /// ## What is Computed Property?
    /// - Property that calculates and returns without storage
    /// - Automatically recalculated when `viewModel.playbackState` changes
    /// - Called every time the View's body is redrawn
    ///
    /// ## Why use Computed Property instead of function?
    /// ```swift
    /// // Function approach
    /// func playPauseIcon() -> String { ... }
    /// Image(systemName: playPauseIcon())  // Requires parentheses
    ///
    /// // Computed Property approach
    /// var playPauseIcon: String { ... }
    /// Image(systemName: playPauseIcon)  // No parentheses needed (more natural)
    /// ```
    ///
    /// ## SF Symbols Icons
    /// - **play.fill**: Filled play icon (▶)
    /// - **pause.fill**: Filled pause icon (❚❚)
    /// - Built into macOS/iOS (30,000+ icons)
    private var playPauseIcon: String {
        switch viewModel.playbackState {
        case .stopped, .paused:
            return "play.fill"
        case .playing:
            return "pause.fill"
        }
    }

    // MARK: - Frame Step Buttons

    /// @brief Frame-by-frame navigation buttons
    ///
    /// ## Functions
    /// - **Previous Frame**: Calls `viewModel.stepBackward()`
    /// - **Next Frame**: Calls `viewModel.stepForward()`
    ///
    /// ## Usage Scenarios
    /// ```
    /// 1. Precise accident moment analysis
    ///    → Identify exact moment by advancing frame by frame
    ///
    /// 2. License plate verification
    ///    → Find clearest moment by advancing one frame at a time while paused
    ///
    /// 3. Find event starting point
    ///    → Find exact frame when impact sensor triggered
    /// ```
    ///
    /// ## SF Symbols Icons
    /// - **backward.frame.fill**: Previous frame (⏮)
    /// - **forward.frame.fill**: Next frame (⏭)
    ///
    /// ## HStack spacing: 8
    /// - 8px gap between two buttons
    /// - Not too close, appropriately separated
    private var frameStepButtons: some View {
        HStack(spacing: 8) {
            Button(action: {
                viewModel.stepBackward()
            }) {
                Image(systemName: "backward.frame.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("Previous frame")

            Button(action: {
                viewModel.stepForward()
            }) {
                Image(systemName: "forward.frame.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("Next frame")
        }
    }

    // MARK: - Event Navigation Buttons

    /// @brief Event navigation buttons
    ///
    /// ## Functions
    /// - **Previous Event**: Navigate to nearest event before current time
    /// - **Next Event**: Navigate to nearest event after current time
    ///
    /// ## Usage Scenarios
    /// ```
    /// 1. Cycle through hard braking events
    ///    → Check all hard braking sections with next event button
    ///
    /// 2. Post-accident analysis
    ///    → Quickly review events before and after accident
    ///
    /// 3. Event comparison
    ///    → Analyze patterns by reviewing multiple events consecutively
    /// ```
    ///
    /// ## SF Symbols Icons
    /// - **chevron.backward.circle.fill**: Previous event
    /// - **chevron.forward.circle.fill**: Next event
    ///
    /// ## Colors
    /// - Orange background: Same family as event markers
    /// - White icon: Clear contrast
    private var eventNavigationButtons: some View {
        HStack(spacing: 8) {
            // Previous event
            Button(action: {
                seekToPreviousEvent()
            }) {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Previous event")
            .disabled(getPreviousEvent() == nil)

            // Next event
            Button(action: {
                seekToNextEvent()
            }) {
                Image(systemName: "chevron.forward.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Next event")
            .disabled(getNextEvent() == nil)
        }
    }

    // MARK: - Event Marker View

    /// @brief Event marker view
    /// @param marker Event marker data
    /// @param width Total timeline width
    /// @return Marker view
    ///
    /// @details
    /// Individual event marker displayed on timeline.
    ///
    /// ## Color Coding
    /// - Hard braking (hardBraking): Red
    /// - Rapid acceleration (rapidAcceleration): Orange
    /// - Sharp turn (sharpTurn): Yellow
    ///
    /// ## Size
    /// - Diameter: 10px
    /// - Opacity adjusted according to magnitude
    private func eventMarkerView(marker: EventMarker, width: CGFloat) -> some View {
        // Calculate marker position
        let position = marker.timestamp / viewModel.duration
        let xOffset = width * position - 5  // Center align (-5 = diameter/2)

        // Color based on event type
        let markerColor: Color = {
            switch marker.type {
            case .hardBraking:
                return .red
            case .rapidAcceleration:
                return .orange
            case .sharpTurn:
                return .yellow
            }
        }()

        return Circle()
            .fill(markerColor)
            .frame(width: 10, height: 10)
            .opacity(0.5 + marker.magnitude * 0.5)  // Adjust opacity based on magnitude
            .offset(x: xOffset, y: 0)
            .onTapGesture {
                // Navigate to corresponding time on marker click
                seekToEvent(marker)
            }
            .help("\(marker.displayName) - \(marker.timeString)")
    }

    // MARK: - Event Navigation Methods

    /// @brief Get previous event
    /// @return Previous event marker (nil if none)
    private func getPreviousEvent() -> EventMarker? {
        let currentTime = viewModel.currentTime
        // Nearest event before current time
        return eventMarkers
            .filter { $0.timestamp < currentTime }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// @brief Get next event
    /// @return Next event marker (nil if none)
    private func getNextEvent() -> EventMarker? {
        let currentTime = viewModel.currentTime
        // Nearest event after current time
        return eventMarkers
            .filter { $0.timestamp > currentTime }
            .min(by: { $0.timestamp < $1.timestamp })
    }

    /// @brief Navigate to previous event
    private func seekToPreviousEvent() {
        guard let event = getPreviousEvent() else { return }
        seekToEvent(event)
    }

    /// @brief Navigate to next event
    private func seekToNextEvent() {
        guard let event = getNextEvent() else { return }
        seekToEvent(event)
    }

    /// @brief Navigate to specific event
    /// @param event Event marker to navigate to
    private func seekToEvent(_ event: EventMarker) {
        viewModel.seek(to: event.timestamp / viewModel.duration)
    }

    // MARK: - Segment Selection Views

    /// @brief Selected segment highlight view
    /// @param inTime Start time (seconds)
    /// @param outTime End time (seconds)
    /// @param width Total timeline width
    /// @return Segment highlight view
    ///
    /// @details
    /// Displays In Point ~ Out Point range as semi-transparent green bar.
    private func segmentHighlightView(inTime: TimeInterval, outTime: TimeInterval, width: CGFloat) -> some View {
        let startPosition = inTime / viewModel.duration
        let endPosition = outTime / viewModel.duration
        let segmentWidth = width * (endPosition - startPosition)
        let xOffset = width * startPosition

        return Rectangle()
            .fill(Color.green.opacity(0.2))
            .frame(width: segmentWidth, height: 4)
            .cornerRadius(2)
            .offset(x: xOffset, y: 0)
    }

    /// @brief In Point marker view
    /// @param inTime Start time (seconds)
    /// @param width Total timeline width
    /// @return In Point marker view
    ///
    /// @details
    /// Displays segment start point as green triangle.
    private func inPointMarkerView(inTime: TimeInterval, width: CGFloat) -> some View {
        let position = inTime / viewModel.duration
        let xOffset = width * position - 6

        return Triangle()
            .fill(Color.green)
            .frame(width: 12, height: 12)
            .offset(x: xOffset, y: -8)
            .help("In Point: \(formatTime(inTime))")
    }

    /// @brief Out Point marker view
    /// @param outTime End time (seconds)
    /// @param width Total timeline width
    /// @return Out Point marker view
    ///
    /// @details
    /// Displays segment end point as green inverted triangle.
    private func outPointMarkerView(outTime: TimeInterval, width: CGFloat) -> some View {
        let position = outTime / viewModel.duration
        let xOffset = width * position - 6

        return Triangle()
            .fill(Color.green)
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(180))  // Rotate to point downward
            .offset(x: xOffset, y: 8)
            .help("Out Point: \(formatTime(outTime))")
    }

    /// @brief Segment selection buttons
    ///
    /// @details
    /// Provides buttons for setting In Point, Out Point, reset, and export.
    private var segmentSelectionButtons: some View {
        HStack(spacing: 8) {
            // In Point set button
            Button(action: {
                viewModel.setInPoint()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 14))
                    Text("In")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.inPoint != nil ? Color.green.opacity(0.3) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Set In Point (start of segment)")

            // Out Point set button
            Button(action: {
                viewModel.setOutPoint()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 14))
                    Text("Out")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.outPoint != nil ? Color.green.opacity(0.3) : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Set Out Point (end of segment)")
            .disabled(viewModel.inPoint == nil)

            // Segment clear button
            if viewModel.inPoint != nil || viewModel.outPoint != nil {
                Button(action: {
                    viewModel.clearSegment()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear segment selection")
            }

            // Segment export button
            if viewModel.hasValidSegment {
                Button(action: {
                    exportSegment()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text("Export")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Export selected segment (\(formatTime(viewModel.segmentDuration)))")
            }
        }
    }

    // MARK: - Snapshot Button

    /// @brief Snapshot button
    ///
    /// @details
    /// Saves current video frame as image file.
    ///
    /// ## Functions
    /// - Capture currently displayed frame
    /// - Support PNG, JPEG, TIFF formats
    /// - Display file save dialog
    ///
    /// ## SF Symbols Icon
    /// - **camera.fill**: Camera icon (snapshot meaning)
    private var snapshotButton: some View {
        Button(action: {
            saveSnapshot()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help("Save current frame as image")
        .disabled(viewModel.currentFrame == nil)
    }

    // MARK: - Share Button

    /// @brief Share button
    ///
    /// @details
    /// Displays macOS native share menu.
    ///
    /// ## Share Options
    /// - Current video file
    /// - Current frame snapshot
    /// - (Future) Extracted segment
    ///
    /// ## SF Symbols Icon
    /// - **square.and.arrow.up**: Share icon (macOS/iOS standard)
    private var shareButton: some View {
        Menu {
            // Share video file
            Button(action: {
                shareVideoFile()
            }) {
                Label("Share Video File", systemImage: "film")
            }
            .disabled(viewModel.videoFile == nil)

            // Share current frame snapshot
            Button(action: {
                shareCurrentFrame()
            }) {
                Label("Share Current Frame", systemImage: "camera")
            }
            .disabled(viewModel.currentFrame == nil)

            Divider()

            // Share segment (only when valid segment exists)
            if viewModel.hasValidSegment {
                Button(action: {
                    shareSegment()
                }) {
                    Label("Share Selected Segment", systemImage: "scissors")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.3))
            .cornerRadius(4)
        }
        .menuStyle(.borderlessButton)
        .help("Share")
    }

    // MARK: - Share Methods

    /// @brief Share video file
    ///
    /// @details
    /// Shares currently playing video file through macOS sharing service.
    ///
    /// ## Available Services
    /// - AirDrop
    /// - Messages
    /// - Mail
    /// - Notes
    /// - Other macOS share extensions
    private func shareVideoFile() {
        guard let videoFile = viewModel.videoFile,
              let frontChannel = videoFile.channel(for: .front) ?? videoFile.channels.first else {
            print("No video file available to share")
            return
        }

        let fileURL = URL(fileURLWithPath: frontChannel.filePath)
        shareItems([fileURL])
    }

    /// @brief Share current frame snapshot
    ///
    /// @details
    /// Captures currently displayed frame as image and shares it.
    /// Saves as PNG format to temporary file then shares.
    private func shareCurrentFrame() {
        guard let snapshot = viewModel.captureCurrentFrame() else {
            print("Failed to capture current frame")
            return
        }

        // Create PNG file in temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "snapshot_\(formatTime(viewModel.currentTime)).png"
        let tempURL = tempDir.appendingPathComponent(fileName)

        // Generate and save PNG data
        guard let tiffData = snapshot.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG data")
            return
        }

        do {
            try pngData.write(to: tempURL)
            shareItems([tempURL])
        } catch {
            print("Failed to save snapshot for sharing: \(error.localizedDescription)")
        }
    }

    /// @brief Share selected segment
    ///
    /// @details
    /// Extracts selected segment to temporary file then shares it.
    /// Share menu is automatically displayed when extraction completes.
    private func shareSegment() {
        guard let inTime = viewModel.inPoint,
              let outTime = viewModel.outPoint,
              let videoFile = viewModel.videoFile else {
            return
        }

        // Create file in temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "segment_\(formatTime(inTime))_to_\(formatTime(outTime)).mp4"
        let tempURL = tempDir.appendingPathComponent(fileName)

        // Execute export
        let exporter = SegmentExporter()
        let duration = outTime - inTime

        guard let frontChannel = videoFile.channel(for: .front) ?? videoFile.channels.first else {
            print("No video channel available")
            return
        }

        exporter.exportSegment(
            inputPath: frontChannel.filePath,
            outputPath: tempURL.path,
            startTime: inTime,
            duration: duration
        ) { progress in
            // Progress log
            DispatchQueue.main.async {
                print("Export progress: \(Int(progress * 100))%")
            }
        } completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    print("Export completed for sharing: \(url)")
                    self.shareItems([url])
                case .failure(let error):
                    print("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// @brief Share items (using macOS sharing service)
    ///
    /// @param items Array of items to share (URL, NSImage, etc.)
    ///
    /// @details
    /// Displays share menu using macOS's NSSharingService.
    ///
    /// ## Shareable Types
    /// - URL: File path
    /// - NSImage: Image
    /// - String: Text
    ///
    /// ## Share Service Examples
    /// - AirDrop: Transfer to nearby device
    /// - Messages: Share via messages
    /// - Mail: Email attachment
    /// - Notes: Add to notes
    private func shareItems(_ items: [Any]) {
        // Display share menu using NSSharingServicePicker
        let picker = NSSharingServicePicker(items: items)

        // Display share menu from current window's contentView
        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView {
            // Get share button's frame and display menu at that position
            // (Here displayed at window center)
            let rect = NSRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 1, height: 1)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }

    // MARK: - Snapshot Save

    /// @brief Execute snapshot save
    ///
    /// @details
    /// Saves current frame as image file.
    /// User can select format (PNG, JPEG, TIFF) and save location.
    ///
    /// ## Save Process
    /// ```
    /// 1. Capture currentFrame (VideoPlayerViewModel.captureCurrentFrame)
    ///      ↓
    /// 2. Display NSSavePanel (select format, select save location)
    ///      ↓
    /// 3. Convert image to selected format (NSBitmapImageRep)
    ///      ↓
    /// 4. Save file
    /// ```
    ///
    /// ## Supported Formats
    /// - **PNG**: Lossless compression, transparency support, medium file size
    /// - **JPEG**: Lossy compression, no transparency, small file size
    /// - **TIFF**: Lossless, high quality, large file size
    private func saveSnapshot() {
        // Capture current frame
        guard let snapshot = viewModel.captureCurrentFrame() else {
            print("Failed to capture current frame")
            return
        }

        // Display file save dialog
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg, .tiff]
        savePanel.nameFieldStringValue = "snapshot_\(formatTime(viewModel.currentTime)).png"
        savePanel.title = "Save Snapshot"
        savePanel.message = "Choose where to save the snapshot"

        savePanel.begin { response in
            guard response == .OK, let outputURL = savePanel.url else {
                return
            }

            // Determine format from selected file extension
            let fileExtension = outputURL.pathExtension.lowercased()
            let imageType: NSBitmapImageRep.FileType

            switch fileExtension {
            case "jpg", "jpeg":
                imageType = .jpeg
            case "tiff", "tif":
                imageType = .tiff
            default:
                imageType = .png
            }

            // Generate image data
            guard let tiffData = snapshot.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData) else {
                print("Failed to create bitmap representation")
                return
            }

            // Convert image data to match format
            let imageProperties: [NSBitmapImageRep.PropertyKey: Any]
            if imageType == .jpeg {
                // JPEG: Quality 0.9 (0.0 = lowest quality, 1.0 = highest quality)
                imageProperties = [.compressionFactor: 0.9]
            } else {
                imageProperties = [:]
            }

            guard let imageData = bitmapImage.representation(using: imageType, properties: imageProperties) else {
                print("Failed to convert image to \(fileExtension) format")
                return
            }

            // Save file
            do {
                try imageData.write(to: outputURL)
                print("Snapshot saved: \(outputURL.path)")
                // TODO: Display success notification
            } catch {
                print("Failed to save snapshot: \(error.localizedDescription)")
                // TODO: Display error notification
            }
        }
    }

    // MARK: - Segment Export

    /// @brief Execute segment export
    ///
    /// @details
    /// Extracts selected segment to separate file.
    /// Displays file save dialog and uses SegmentExporter for extraction.
    private func exportSegment() {
        guard let inTime = viewModel.inPoint,
              let outTime = viewModel.outPoint,
              let videoFile = viewModel.videoFile else {
            return
        }

        // Display file save dialog
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = "segment_\(formatTime(inTime))_to_\(formatTime(outTime)).mp4"
        savePanel.title = "Export Segment"
        savePanel.message = "Choose where to save the exported segment"

        savePanel.begin { response in
            guard response == .OK, let outputURL = savePanel.url else {
                return
            }

            // Execute export
            let exporter = SegmentExporter()
            let duration = outTime - inTime

            // Select front camera channel
            guard let frontChannel = videoFile.channel(for: .front) ?? videoFile.channels.first else {
                print("No video channel available")
                return
            }

            exporter.exportSegment(
                inputPath: frontChannel.filePath,
                outputPath: outputURL.path,
                startTime: inTime,
                duration: duration
            ) { progress in
                // Update progress (main thread)
                DispatchQueue.main.async {
                    // TODO: Update progress UI
                    print("Export progress: \(Int(progress * 100))%")
                }
            } completion: { result in
                // Handle completion (main thread)
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        print("Export completed: \(url)")
                    // TODO: Display success notification
                    case .failure(let error):
                        print("Export failed: \(error.localizedDescription)")
                    // TODO: Display error notification
                    }
                }
            }
        }
    }

    /// @brief Format time as MM:SS
    /// @param time Time (seconds)
    /// @return Formatted time string
    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Time Display

    /// @brief Time display
    ///
    /// ## Display Format
    /// ```
    /// 00:18 / 01:00
    /// ^Current  ^Total
    /// ```
    ///
    /// ## Importance of Monospaced Font
    /// ```swift
    /// .font(.system(.body, design: .monospaced))
    /// ```
    ///
    /// **Regular Font (Proportional):**
    /// ```
    /// "1" width: Narrow
    /// "0" width: Wide
    /// → Width changes when time changes → UI shifts ❌
    /// ```
    ///
    /// **Monospaced Font:**
    /// ```
    /// All digit widths: Same
    /// → Width constant even when time changes → Stable UI ✅
    /// ```
    ///
    /// **Actual Example:**
    /// ```
    /// Regular font:
    /// 00:01 (narrow)
    /// 11:11 (wide) → Width change pushes surrounding UI
    ///
    /// Monospaced:
    /// 00:01 (fixed)
    /// 11:11 (fixed) → Constant width, stable UI
    /// ```
    ///
    /// ## .foregroundColor(.secondary)
    /// - Display total time slightly darker
    /// - Visually express less importance than current time (primary)
    private var timeDisplay: some View {
        HStack(spacing: 4) {
            Text(viewModel.currentTimeString)
                .font(.system(.body, design: .monospaced))

            Text("/")
                .foregroundColor(.secondary)

            Text(viewModel.durationString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Speed Control

    /// @brief Playback speed control
    ///
    /// ## Menu Component Structure
    /// ```swift
    /// Menu {
    ///     // Menu items (appear on click)
    ///     Button("0.5x") { ... }
    ///     Button("0.75x") { ... }
    /// } label: {
    ///     // Button that opens menu (always visible)
    ///     Text("1.0x")
    /// }
    /// ```
    ///
    /// ## Dynamic Menu Generation with ForEach
    /// ```swift
    /// ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
    ///     Button(action: { viewModel.setPlaybackSpeed(speed) }) {
    ///         HStack {
    ///             Text(String(format: "%.2fx", speed))
    ///             if abs(viewModel.playbackSpeed - speed) < 0.01 {
    ///                 Image(systemName: "checkmark")
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// **Meaning of id: \.self:**
    /// - ForEach needs an ID to distinguish each item
    /// - `\.self` uses the value itself as ID (0.5, 0.75, 1.0, etc.)
    /// - Double is Hashable so can be used as ID
    ///
    /// ## Checkmark Display Logic
    /// ```swift
    /// if abs(viewModel.playbackSpeed - speed) < 0.01 {
    ///     Image(systemName: "checkmark")
    /// }
    /// ```
    ///
    /// **Why use abs()?**
    /// - Double comparison shouldn't use == due to floating point error
    /// - Example: `1.0 == 1.0000000001` → false (error)
    /// - Solution: `abs(1.0 - 1.0000000001) < 0.01` → true (close enough)
    ///
    /// ## String.format() Usage
    /// ```swift
    /// String(format: "%.2fx", 0.5)   → "0.50x"
    /// String(format: "%.2fx", 1.0)   → "1.00x"
    /// String(format: "%.2fx", 1.25)  → "1.25x"
    ///
    /// // Meaning of %.2f
    /// %     → Format specifier start
    /// .2    → 2 decimal places
    /// f     → float/double type
    /// x     → Regular text (speed unit)
    /// ```
    ///
    /// ## .menuStyle(.borderlessButton)
    /// - macOS-specific style
    /// - Display cleanly without button border
    private var speedControl: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: {
                    viewModel.setPlaybackSpeed(speed)
                }) {
                    HStack {
                        Text(String(format: "%.2fx", speed))
                        if abs(viewModel.playbackSpeed - speed) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge")
                Text(viewModel.playbackSpeedString)
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
        }
        .menuStyle(.borderlessButton)
        .help("Playback speed")
    }

    // MARK: - Volume Control

    /// @brief Volume control
    ///
    /// ## Binding(get:set:) Pattern
    /// ```swift
    /// Slider(value: Binding(
    ///     get: { viewModel.volume },           // Read value
    ///     set: { viewModel.setVolume($0) }     // Write value
    /// ), in: 0...1)
    /// ```
    ///
    /// ## What is Binding?
    /// - Property Wrapper that provides two-way data binding
    /// - Allows Slider, TextField, etc. to read and write values
    ///
    /// ## Why use Binding(get:set:)?
    ///
    /// ### Method 1: Direct @State Binding (Simple Case)
    /// ```swift
    /// @State private var volume: Double = 0.5
    /// Slider(value: $volume, in: 0...1)
    /// // ✅ Simple, but cannot execute additional logic on value change
    /// ```
    ///
    /// ### Method 2: Binding(get:set:) (When Additional Logic Needed)
    /// ```swift
    /// Slider(value: Binding(
    ///     get: { viewModel.volume },
    ///     set: { viewModel.setVolume($0) }  // Also set audio volume
    /// ), in: 0...1)
    /// // ✅ Calls setVolume() method on value change → Controls audio output
    /// ```
    ///
    /// ## What setVolume(_:) Does
    /// ```swift
    /// func setVolume(_ newVolume: Double) {
    ///     volume = newVolume                // 1. Update property
    ///     audioPlayer.setVolume(newVolume)  // 2. Control audio output
    ///     UserDefaults.save(volume: newVolume)  // 3. Save settings (optional)
    /// }
    /// ```
    ///
    /// ## HStack spacing: 8
    /// - 8px gap between icon and slider
    /// - Visually connected but not touching
    ///
    /// ## .frame(width: 80)
    /// - Fixed slider width
    /// - Maintain layout even when volume icon changes
    private var volumeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            Slider(value: Binding(
                get: { viewModel.volume },
                set: { viewModel.setVolume($0) }
            ), in: 0...1)
            .frame(width: 80)
        }
    }

    /// @brief Volume icon (Computed Property)
    ///
    /// ## Icons by Volume Level
    /// ```
    /// Volume = 0.00       → "speaker.slash.fill"   (🔇 muted)
    /// Volume = 0.01~0.32  → "speaker.wave.1.fill"  (🔈 low)
    /// Volume = 0.33~0.66  → "speaker.wave.2.fill"  (🔉 medium)
    /// Volume = 0.67~1.00  → "speaker.wave.3.fill"  (🔊 high)
    /// ```
    ///
    /// ## Range Division Logic
    /// ```swift
    /// if volume == 0 { ... }         // Exactly 0
    /// else if volume < 0.33 { ... }  // 0.01 ~ 0.32
    /// else if volume < 0.67 { ... }  // 0.33 ~ 0.66
    /// else { ... }                   // 0.67 ~ 1.00
    /// ```
    ///
    /// **Why divide into thirds?**
    /// - 4 levels allow user intuitive understanding
    /// - Corresponds to 3 wave icons (1 wave, 2 waves, 3 waves)
    ///
    /// ## SF Symbols Speaker Icons
    /// - **speaker.slash.fill**: Speaker with slash (muted)
    /// - **speaker.wave.1.fill**: 1 wave (low volume)
    /// - **speaker.wave.2.fill**: 2 waves (medium volume)
    /// - **speaker.wave.3.fill**: 3 waves (high volume)
    ///
    /// ## Effect of .frame(width: 20)
    /// - Fix icon width to 20px
    /// - Layout not affected when icon changes
    ///
    /// **Example:**
    /// ```
    /// Without fixed icon width:
    /// 🔇 (narrow)
    /// 🔊 (wide) → Slider position changes when icon changes ❌
    ///
    /// With .frame(width: 20):
    /// 🔇 (20px)
    /// 🔊 (20px) → Always same width, slider position fixed ✅
    /// ```
    private var volumeIcon: String {
        if viewModel.volume == 0 {
            return "speaker.slash.fill"
        } else if viewModel.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if viewModel.volume < 0.67 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Preview

/// @brief Preview (temporarily disabled - requires sample data)
//
// To enable Preview, create a Mock ViewModel as follows:
//
// ```swift
// extension VideoPlayerViewModel {
//     static func mock() -> VideoPlayerViewModel {
//         let vm = VideoPlayerViewModel()
//         vm.playbackState = .paused
//         vm.playbackPosition = 0.3  // 30% played
//         vm.currentTimeString = "00:18"
//         vm.durationString = "01:00"
//         vm.playbackSpeed = 1.0
//         vm.volume = 0.7
//         return vm
//     }
// }
//
// struct PlayerControlsView_Previews: PreviewProvider {
//     static var previews: some View {
//         VStack(spacing: 20) {
//             // Playing state
//             PlayerControlsView(viewModel: {
//                 let vm = VideoPlayerViewModel.mock()
//                 vm.playbackState = .playing
//                 return vm
//             }())
//             .previewDisplayName("Playing")
//
//             // Paused state
//             PlayerControlsView(viewModel: {
//                 let vm = VideoPlayerViewModel.mock()
//                 vm.playbackState = .paused
//                 return vm
//             }())
//             .previewDisplayName("Paused")
//
//             // Muted state
//             PlayerControlsView(viewModel: {
//                 let vm = VideoPlayerViewModel.mock()
//                 vm.volume = 0
//                 return vm
//             }())
//             .previewDisplayName("Muted")
//         }
//         .frame(height: 100)
//         .padding()
//     }
// }
// ```
//
// struct PlayerControlsView_Previews: PreviewProvider {
//     static var previews: some View {
//         PlayerControlsView(viewModel: VideoPlayerViewModel())
//             .frame(height: 100)
//     }
// }

// MARK: - Triangle Shape

/// @struct Triangle
/// @brief Triangle Shape
///
/// @details
/// Triangle path for In/Out Point markers.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Triangle vertex (top center)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))

        // Bottom left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        // Bottom right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // Close (back to vertex)
        path.closeSubpath()

        return path
    }
}
