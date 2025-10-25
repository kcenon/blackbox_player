/// @file VideoPlayerViewModel.swift
/// @brief Video Player ViewModel
/// @author BlackboxPlayer Development Team
/// @details ViewModel class that manages video player state and playback logic.
///
/// ## What is the MVVM Pattern?
/// The Model-View-ViewModel pattern manages UI (View) and business logic (ViewModel) separately.
///
/// ```
/// ┌─────────┐     @Published     ┌──────────────┐
/// │  Model  │ ──────────────────> │  ViewModel   │ (This class)
/// │ (Data)  │                     │(Business Logic)│
/// └─────────┘                     └──────────────┘
///                                        ↑ ↓ @Published
///                                  Auto Update (Combine)
///                                        ↓ ↑
///                                 ┌──────────────┐
///                                 │     View     │
///                                 │     (UI)     │
///                                 └──────────────┘
/// ```
///
/// ## Key Features
/// - **Video Loading**: VideoFile → Initialize VideoDecoder → Load first frame
/// - **Playback Control**: play(), pause(), stop(), seek(), stepForward/Backward()
/// - **State Management**: Auto-update playbackState, currentTime, playbackPosition, currentFrame etc. via @Published
/// - **Audio Synchronization**: Synchronized video/audio playback via AudioPlayer integration
/// - **Timer-based Playback**: Periodic frame decoding according to frame rate (FPS)
///
/// ## What are ObservableObject and @Published?
/// ### ObservableObject
/// - Protocol that defines an observable object in SwiftUI
/// - Automatically notifies View when @Published properties change
///
/// ### @Published
/// - Notifies SwiftUI whenever property value changes
/// - View automatically re-renders
///
/// **Operation Flow:**
/// ```swift
/// // ViewModel (This class)
/// class VideoPlayerViewModel: ObservableObject {
///     @Published var currentTime: TimeInterval = 0.0  // Detect changes
/// }
///
/// // View (SwiftUI)
/// struct PlayerView: View {
///     @ObservedObject var viewModel: VideoPlayerViewModel  // Observe
///
///     var body: some View {
///         Text("\(viewModel.currentTime)")  // Auto re-render when currentTime changes
///     }
/// }
///
/// // Operation Example
/// viewModel.currentTime = 5.0  // Value changes
///      ↓ @Published detects
/// Combine framework sends notification
///      ↓
/// @ObservedObject receives notification
///      ↓
/// View auto re-renders (Text updates to "5.0")
/// ```
///
/// ## Playback Algorithm
/// ### Timer-based Playback
/// ```
/// 1. Call play()
///      ↓
/// 2. startPlaybackTimer() → Create Timer
///      ↓ Period: Execute every (1 / frameRate) / playbackSpeed seconds
/// 3. Repeatedly call updatePlayback()
///      ↓
/// 4. decoder.decodeNextFrame() → Decode next frame
///      ↓
/// 5. Update currentFrame, currentTime (@Published → Auto refresh View)
///      ↓
/// 6. audioPlayer.enqueue(audioFrame) → Play audio
///      ↓
/// 7. stop() when end of file (EOF) is reached
/// ```
///
/// **Frame Rate Calculation Example:**
/// ```swift
/// targetFrameRate = 30.0  // 30 FPS
/// playbackSpeed = 1.0     // 1x speed
///
/// interval = (1.0 / 30.0) / 1.0 = 0.0333 seconds (approx 33ms)
/// → Call updatePlayback() every 33ms
///
/// playbackSpeed = 2.0     // 2x speed
/// interval = (1.0 / 30.0) / 2.0 = 0.0167 seconds (approx 17ms)
/// → Call updatePlayback() every 17ms (2x faster)
/// ```
///
/// ## Seek Algorithm
/// ```
/// 1. Call seek(to: position)
///      ↓ Clamp position to 0.0~1.0
/// 2. Calculate targetTime = position * duration
///      ↓
/// 3. decoder.seek(to: targetTime) → Decoder seek
///      ↓
/// 4. audioPlayer.flush() → Clear audio buffer
///      ↓
/// 5. loadFrameAt(time:) → Load frame at that time
///      ↓
/// 6. Update currentTime, playbackPosition
/// ```
///
/// ## Usage Example
/// ```swift
/// // 1. Create ViewModel
/// let viewModel = VideoPlayerViewModel()
///
/// // 2. Load video
/// let videoFile = VideoFile(...)
/// viewModel.loadVideo(videoFile)
/// //   → Initialize decoder
/// //   → Load first frame
/// //   → playbackState = .paused
///
/// // 3. Start playback
/// viewModel.play()
/// //   → playbackState = .playing
/// //   → Start Timer (call updatePlayback frame by frame)
///
/// // 4. Seek to specific position
/// viewModel.seek(to: 0.5)  // Move to 50% position
/// //   → currentTime = duration * 0.5
/// //   → Load frame at that position
///
/// // 5. Adjust playback speed
/// viewModel.setPlaybackSpeed(2.0)  // 2x speed
/// //   → Readjust Timer interval (2x faster)
///
/// // 6. Pause
/// viewModel.pause()
/// //   → playbackState = .paused
/// //   → Stop Timer
///
/// // 7. Stop
/// viewModel.stop()
/// //   → playbackState = .stopped
/// //   → Release all resources
/// ```
///
/// ## Real Usage Scenarios
/// **Scenario 1: Video Loading and Playback**
/// ```
/// 1. Call loadVideo(videoFile)
///      ↓
/// 2. Initialize VideoDecoder (FFmpeg)
///      ↓
/// 3. Get video information (duration, frameRate)
///      ↓
/// 4. Initialize AudioPlayer (if audio stream exists)
///      ↓
/// 5. Load first frame (time: 0)
///      ↓
/// 6. playbackState = .paused (Ready to play)
///      ↓ Enable Play button in View
/// 7. Call play() (User clicks Play button)
///      ↓
/// 8. Start Timer → Play frame by frame
/// ```
///
/// **Scenario 2: Move to Specific Moment (Seek)**
/// ```
/// 1. User drags timeline slider
///      ↓
/// 2. Call seek(to: 0.75) (75% position)
///      ↓
/// 3. Calculate targetTime = 90 * 0.75 = 67.5 seconds
///      ↓
/// 4. decoder.seek(to: 67.5) → Execute FFmpeg seek
///      ↓
/// 5. audioPlayer.flush() → Clear audio buffer
///      ↓
/// 6. loadFrameAt(time: 67.5) → Decode frame at 67.5 seconds
///      ↓
/// 7. Update currentTime = 67.5, playbackPosition = 0.75
///      ↓ @Published → Auto refresh View
/// 8. Timeline slider moves to 75% position
/// ```
///
/// **Scenario 3: Frame-by-Frame Movement (Step Forward)**
/// ```
/// 1. Call stepForward()
///      ↓
/// 2. Calculate frameTime = 1.0 / 30.0 = 0.0333 seconds (30 FPS)
///      ↓
/// 3. Call seekToTime(currentTime + frameTime)
///      ↓ currentTime = 5.0 seconds
/// 4. seekToTime(5.0333) → Move to next frame
///      ↓
/// 5. Decode and display corresponding frame
/// ```
//
//  VideoPlayerViewModel.swift
//  BlackboxPlayer
//
//  ViewModel for video player state management
//

import Foundation
import Combine
import SwiftUI

/// @class VideoPlayerViewModel
/// @brief Video Player State Management ViewModel
/// @details Manages video playback logic and state using the MVVM pattern.
///
/// ## ObservableObject
/// - Used with SwiftUI's @ObservedObject and @StateObject
/// - Automatically notifies View when @Published properties change
///
/// **Usage Example:**
/// ```swift
/// struct PlayerView: View {
///     @StateObject private var viewModel = VideoPlayerViewModel()
///
///     var body: some View {
///         VStack {
///             // Text automatically updates when currentTime changes
///             Text("\(viewModel.currentTimeString)")
///
///             Button("Play") {
///                 viewModel.play()  // Start playback
///             }
///         }
///     }
/// }
/// ```
class VideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties

    /// @var playbackState
    /// @brief Current playback state
    /// @details Stores one of three states: stopped, playing, or paused.
    ///
    /// ## PlaybackState
    /// - .stopped: Stopped state (before video load or after stop)
    /// - .playing: Playing (Timer running)
    /// - .paused: Paused (Timer stopped, state maintained)
    ///
    /// ## @Published
    /// - Automatically notifies View when value changes
    /// - View re-renders to update UI
    ///
    /// **State Transition Examples:**
    /// ```
    /// loadVideo() → .paused   (Loading complete, ready to play)
    /// play()      → .playing  (Start playback)
    /// pause()     → .paused   (Pause)
    /// stop()      → .stopped  (Stop and release resources)
    /// EOF reached → .stopped  (End of file)
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// if viewModel.playbackState == .playing {
    ///     Image(systemName: "pause.fill")  // Playing → Pause icon
    /// } else {
    ///     Image(systemName: "play.fill")   // Stopped/Paused → Play icon
    /// }
    /// ```
    @Published var playbackState: PlaybackState = .stopped

    /// @var playbackPosition
    /// @brief Current playback position (0.0 ~ 1.0)
    /// @details Expresses video playback position as a ratio.
    ///
    /// ## Ratio Representation
    /// - 0.0: Start position (0%)
    /// - 0.5: Middle position (50%)
    /// - 1.0: End position (100%)
    ///
    /// ## Calculation Formula
    /// ```swift
    /// playbackPosition = currentTime / duration
    /// ```
    ///
    /// **Examples:**
    /// ```swift
    /// currentTime = 45 seconds, duration = 90 seconds
    /// playbackPosition = 45 / 90 = 0.5 (50%)
    ///
    /// currentTime = 90 seconds, duration = 90 seconds
    /// playbackPosition = 90 / 90 = 1.0 (100%)
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Slider(value: $viewModel.playbackPosition)  // Timeline slider
    ///     .onChange(of: playbackPosition) { newValue in
    ///         viewModel.seek(to: newValue)  // Seek on slider drag
    ///     }
    /// ```
    @Published var playbackPosition: Double = 0.0

    /// @var currentTime
    /// @brief Current playback time (in seconds)
    /// @details Double type allows decimal time representation.
    ///
    /// ## TimeInterval
    /// - Double type (decimal values allowed)
    /// - Unit: seconds
    ///
    /// **Examples:**
    /// ```swift
    /// currentTime = 0.0    → Start position
    /// currentTime = 45.5   → 45.5 seconds (0 min 45.5 sec)
    /// currentTime = 125.0  → 125 seconds (2 min 5 sec)
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Text(viewModel.currentTimeString)  // Display as "02:05" format
    /// ```
    @Published var currentTime: TimeInterval = 0.0

    /// Total playback time (in seconds)
    ///
    /// ## Video Length
    /// - Obtained from VideoDecoder.getDuration() or VideoFile.duration
    /// - Represents total file length
    ///
    /// **Examples:**
    /// ```swift
    /// duration = 90.0   → 1 minute 30 seconds video
    /// duration = 600.0  → 10 minutes video
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Text("\(viewModel.currentTimeString) / \(viewModel.durationString)")
    /// // Display as "01:30 / 10:00" format
    /// ```
    @Published var duration: TimeInterval = 0.0

    /// @var currentFrame
    /// @brief Current video frame
    /// @details Stores the decoded VideoFrame object.
    ///
    /// ## VideoFrame
    /// - Decoded video frame (image + timestamp)
    /// - Obtained from decoder.decodeNextFrame() in updatePlayback()
    ///
    /// ## Why Optional
    /// - Before video load: nil
    /// - Decoding failure: nil
    /// - Stopped state: nil
    ///
    /// **Examples:**
    /// ```swift
    /// // Before video load
    /// currentFrame = nil
    ///
    /// // During playback
    /// currentFrame = VideoFrame(image: CGImage(...), timestamp: 1.5)
    ///
    /// // Usage in View
    /// if let frame = viewModel.currentFrame {
    ///     Image(frame.image, scale: 1.0, label: Text("Video"))
    /// }
    /// ```
    @Published var currentFrame: VideoFrame?

    /// Playback speed (0.5x ~ 4.0x)
    ///
    /// ## Speed Multiplier
    /// - 0.5: 0.5x speed (slower)
    /// - 1.0: Normal speed (default)
    /// - 2.0: 2x speed (faster)
    ///
    /// ## Speed Control Implementation
    /// - Implemented by adjusting Timer interval
    /// - interval = (1.0 / frameRate) / playbackSpeed
    ///
    /// **Examples:**
    /// ```swift
    /// frameRate = 30.0, playbackSpeed = 1.0
    /// interval = (1.0 / 30.0) / 1.0 = 0.0333 seconds (33ms)
    ///
    /// frameRate = 30.0, playbackSpeed = 2.0
    /// interval = (1.0 / 30.0) / 2.0 = 0.0167 seconds (17ms) ← 2x faster
    ///
    /// frameRate = 30.0, playbackSpeed = 0.5
    /// interval = (1.0 / 30.0) / 0.5 = 0.0667 seconds (67ms) ← 2x slower
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Menu {
    ///     Button("0.5x") { viewModel.setPlaybackSpeed(0.5) }
    ///     Button("1.0x") { viewModel.setPlaybackSpeed(1.0) }
    ///     Button("2.0x") { viewModel.setPlaybackSpeed(2.0) }
    /// } label: {
    ///     Text(viewModel.playbackSpeedString)  // Display "1.0x"
    /// }
    /// ```
    @Published var playbackSpeed: Double = 1.0

    /// Volume (0.0 ~ 1.0)
    ///
    /// ## Volume Range
    /// - 0.0: Mute
    /// - 0.5: 50% volume
    /// - 1.0: Maximum volume (100%)
    ///
    /// ## Audio Player Integration
    /// - Passed via audioPlayer.setVolume(Float(volume))
    ///
    /// **Examples:**
    /// ```swift
    /// volume = 0.0   → audioPlayer.setVolume(0.0) → Mute
    /// volume = 0.75  → audioPlayer.setVolume(0.75) → 75% volume
    /// volume = 1.0   → audioPlayer.setVolume(1.0) → Maximum volume
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Slider(value: $viewModel.volume, in: 0...1)
    ///     .onChange(of: volume) { newValue in
    ///         viewModel.setVolume(newValue)
    ///     }
    /// ```
    @Published var volume: Double = 1.0

    /// Whether buffering is in progress
    ///
    /// ## Buffering State
    /// - true: Frame loading in progress (loadFrameAt executing)
    /// - false: Loading complete or no loading
    ///
    /// ## Purpose
    /// - Display loading indicator in UI
    /// - Notify user that seek is in progress
    ///
    /// **Operation Example:**
    /// ```
    /// Call seekToTime(30.0)
    ///      ↓
    /// isBuffering = true (Buffering starts)
    ///      ↓
    /// decoder.seek(to: 30.0) → Execute FFmpeg seek
    ///      ↓
    /// decoder.decodeNextFrame() → Decode frame
    ///      ↓
    /// isBuffering = false (Buffering complete)
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// if viewModel.isBuffering {
    ///     ProgressView()  // Display loading indicator
    /// }
    /// ```
    @Published var isBuffering: Bool = false

    /// Error message
    ///
    /// ## Why Optional
    /// - No error: nil
    /// - Error occurred: Error message string
    ///
    /// ## Error Occurrence Timing
    /// - Video loading failure
    /// - Decoding error
    /// - Seek failure
    ///
    /// **Examples:**
    /// ```swift
    /// // Normal state
    /// errorMessage = nil
    ///
    /// // Error occurred
    /// errorMessage = "Failed to load video: File not found"
    /// errorMessage = "Seek failed: Invalid timestamp"
    /// errorMessage = "Cannot play corrupted video file"
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// if let error = viewModel.errorMessage {
    ///     Text(error)
    ///         .foregroundColor(.red)  // Display error message in red
    /// }
    /// ```
    @Published var errorMessage: String?

    /// Segment start point (In Point)
    ///
    /// ## Segment Extraction
    /// - Start time of segment to extract (seconds)
    /// - nil: Start point not set
    /// - Range: 0.0 ~ duration
    ///
    /// **Usage Examples:**
    /// ```swift
    /// viewModel.setInPoint()         // Set current time as start point
    /// viewModel.inPoint              // 5.0 (5 seconds)
    /// viewModel.clearInPoint()       // Reset to nil
    /// ```
    @Published var inPoint: TimeInterval?

    /// Segment end point (Out Point)
    ///
    /// ## Segment Extraction
    /// - End time of segment to extract (seconds)
    /// - nil: End point not set
    /// - Range: 0.0 ~ duration
    /// - Must be greater than inPoint
    ///
    /// **Usage Examples:**
    /// ```swift
    /// viewModel.setOutPoint()        // Set current time as end point
    /// viewModel.outPoint             // 15.0 (15 seconds)
    /// viewModel.clearOutPoint()      // Reset to nil
    /// ```
    @Published var outPoint: TimeInterval?

    // MARK: - Private Properties

    /// Video decoder (FFmpeg wrapper)
    ///
    /// ## VideoDecoder
    /// - Video/audio decoder wrapping FFmpeg
    /// - Handles video file decoding, seeking, frame extraction
    ///
    /// ## Why Optional
    /// - Before video load: nil
    /// - Loading failure: nil
    /// - When stop() called: Reset to nil (release resources)
    private var decoder: VideoDecoder?

    /// Currently loaded video file information
    ///
    /// ## VideoFile
    /// - Contains file path, metadata, channel information, etc.
    /// - Received from loadVideo()
    ///
    /// ## Usage Purpose
    /// - Reference video information (duration, channels, etc.)
    /// - Access metadata (GPS, acceleration data)
    /// - Access channel information during segment extraction
    ///
    /// ## Access Control
    /// - internal: Needs to be accessed from PlayerControlsView for segment extraction
    var videoFile: VideoFile?

    /// Playback timer
    ///
    /// ## Timer
    /// - Foundation's Timer class
    /// - Calls updatePlayback() at regular intervals
    ///
    /// ## Operation Principle
    /// ```
    /// startPlaybackTimer()
    ///      ↓
    /// Timer.scheduledTimer(withTimeInterval: 0.0333, repeats: true)
    ///      ↓ Repeats every 33ms (30 FPS)
    /// Call updatePlayback()
    ///      ↓
    /// decoder.decodeNextFrame() → Decode frame
    ///      ↓
    /// Update currentFrame, currentTime
    /// ```
    ///
    /// ## Why Optional
    /// - Stopped/paused state: nil (no timer)
    /// - Playing: Timer object (timer active)
    private var playbackTimer: Timer?

    /// Target frame rate (FPS)
    ///
    /// ## Frame Rate
    /// - Obtained from VideoDecoder.videoInfo.frameRate
    /// - Unit: fps (frames per second)
    ///
    /// **Examples:**
    /// ```swift
    /// targetFrameRate = 30.0  → 30 FPS (30 frames per second)
    /// targetFrameRate = 60.0  → 60 FPS (60 frames per second)
    /// ```
    ///
    /// ## Usage Purpose
    /// - Timer interval calculation: interval = (1.0 / targetFrameRate) / playbackSpeed
    /// - stepForward/Backward: frameTime = 1.0 / targetFrameRate
    private var targetFrameRate: Double = 30.0

    /// Audio player
    ///
    /// ## AudioPlayer
    /// - Player that plays audio frames
    /// - Receives and plays audio frames from VideoDecoder
    ///
    /// ## Why Optional
    /// - No audio stream: nil
    /// - Audio player initialization failure: nil
    /// - When playing video only: nil
    ///
    /// ## Synchronization Method
    /// ```
    /// updatePlayback()
    ///      ↓
    /// decoder.decodeNextFrame() → { video: VideoFrame, audio: AudioFrame }
    ///      ↓
    /// currentFrame = videoFrame (Display video)
    /// audioPlayer.enqueue(audioFrame) (Play audio)
    ///      ↓
    /// Video and audio play synchronized
    /// ```
    private var audioPlayer: AudioPlayer?

    // ============================================
    // MARK: Performance Optimization (Large File Handling)
    // ============================================

    /// @var frameCache
    /// @brief Recently decoded frame cache
    ///
    /// ## Purpose of Frame Cache
    /// - Keep recently played frames in memory
    /// - Improve performance for reverse playback, repeat playback
    /// - Enable immediate frame display after seek
    ///
    /// ## Cache Key
    /// - Timestamp rounded to 100ms units
    /// - Example: 1.234 seconds → 1.2 seconds, 1.278 seconds → 1.3 seconds
    ///
    /// ## Memory Management
    /// - Maximum cache size limit (maxFrameCacheSize)
    /// - Automatic removal of old entries (LRU method)
    ///
    /// **Examples:**
    /// ```
    /// 1080p RGBA frame = approx 8.3MB
    /// Cache 30 frames = approx 249MB
    /// Cache 60 frames = approx 498MB
    /// ```
    private var frameCache: [TimeInterval: VideoFrame] = [:]

    /// @var maxFrameCacheSize
    /// @brief Maximum frame cache size
    ///
    /// ## Cache Size Determination
    /// - Default: 30 frames
    /// - Approximately 1 second for 30fps video
    /// - Memory usage: approx 250MB (1080p RGBA basis)
    ///
    /// ## Size Adjustment Considerations
    /// - High-memory systems: 60~120 frames
    /// - Low-memory systems: 15~20 frames
    /// - High resolution (4K): 10~15 frames
    private let maxFrameCacheSize: Int = 30

    /// @var lastCacheCleanupTime
    /// @brief Last cache cleanup time
    ///
    /// ## Periodic Cache Cleanup
    /// - Remove old cache entries at regular intervals
    /// - Relieve memory pressure
    private var lastCacheCleanupTime = Date()

    /// @var memoryWarningObserver
    /// @brief Memory warning notification observer
    ///
    /// ## Memory Warning Handling
    /// - iOS/macOS sends notification when memory is low
    /// - Immediately clean frame cache when notification received
    /// - Prevent app termination by relieving memory pressure
    ///
    /// **Memory Warning Scenarios:**
    /// - Other apps using a lot of memory
    /// - Playing large video files
    /// - Multiple channels playing simultaneously
    /// - System available memory low
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Initialization

    /// Initialize ViewModel
    ///
    /// ## Empty Initialization
    /// - All properties initialized with default values
    /// - Video loaded separately via loadVideo()
    /// - Register memory warning observer
    ///
    /// **Usage Example:**
    /// ```swift
    /// let viewModel = VideoPlayerViewModel()
    /// viewModel.loadVideo(videoFile)  // Load video
    /// ```
    init() {
        /// Register memory warning observer
        ///
        /// ## NotificationCenter
        /// - iOS/macOS notification system
        /// - Broadcast/subscribe to events across the app
        ///
        /// ## didReceiveMemoryWarningNotification
        /// - Sent by UIApplication (iOS) or NSApplication (macOS)
        /// - Notifies all subscribers when memory is low
        ///
        /// **Operation:**
        /// ```
        /// System detects low memory
        ///      ↓
        /// Send didReceiveMemoryWarningNotification
        ///      ↓
        /// Automatically call handleMemoryWarning()
        ///      ↓
        /// Clean frame cache (release up to 250MB)
        /// ```
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSApplicationDidReceiveMemoryWarningNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    /// Called when ViewModel is deallocated
    ///
    /// ## deinit
    /// - Automatically called when object is deallocated from memory
    /// - Clean up resources (timer, decoder, audio player, etc.)
    /// - Remove memory warning observer
    ///
    /// **Operation:**
    /// ```
    /// viewModel = nil (Deallocate ViewModel)
    ///      ↓
    /// deinit automatically called
    ///      ↓
    /// Remove memory warning observer
    ///      ↓
    /// stop() → Stop timer, stop audio, release decoder
    /// ```
    deinit {
        /// Remove memory warning observer
        ///
        /// ## removeObserver
        /// - Remove observer from NotificationCenter
        /// - Prevent memory leak (break retain cycle)
        /// - ViewModel may remain in memory if not removed
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        /// Clean up existing resources
        stop()
    }

    // MARK: - Public Methods

    /// Load video file
    ///
    /// ## Loading Process
    /// ```
    /// 1. Stop current playback (stop())
    ///      ↓
    /// 2. Check file corruption (videoFile.isCorrupted)
    ///      ↓
    /// 3. Select front camera channel (or first channel)
    ///      ↓
    /// 4. Initialize VideoDecoder (FFmpeg)
    ///      ↓
    /// 5. Get duration, frameRate
    ///      ↓
    /// 6. Load first frame (time: 0)
    ///      ↓
    /// 7. Initialize AudioPlayer (if audio stream exists)
    ///      ↓
    /// 8. playbackState = .paused (Ready to play)
    /// ```
    ///
    /// ## Error Handling
    /// - Corrupted file: Set errorMessage, playbackState = .stopped
    /// - No channel: Set errorMessage
    /// - Decoder initialization failure: Set errorMessage, playbackState = .stopped
    ///
    /// - Parameter videoFile: Video file to load
    ///
    /// **Usage Example:**
    /// ```swift
    /// let videoFile = VideoFile(filePath: "/path/to/video.mp4", ...)
    /// viewModel.loadVideo(videoFile)
    ///
    /// // On success
    /// // playbackState = .paused
    /// // currentFrame = First frame
    /// // duration = 90.0 (90 seconds)
    ///
    /// // On failure
    /// // playbackState = .stopped
    /// // errorMessage = "Failed to load video: ..."
    /// ```
    func loadVideo(_ videoFile: VideoFile) {
        /// Step 1: Stop current playback
        ///
        /// ## stop()
        /// - Clean up if a video is currently playing
        /// - Release timer, decoder, audio player
        stop()

        /// Step 2: Store file information
        self.videoFile = videoFile

        /// Step 3: Check file corruption
        ///
        /// ## videoFile.isCorrupted
        /// - true if corruption detected during file scan
        /// - Corrupted files cannot be played
        ///
        /// **Corruption Examples:**
        /// - File header corruption
        /// - Incomplete download
        /// - Error during save
        if videoFile.isCorrupted {
            errorMessage = "Cannot play corrupted video file. The file may be damaged or incomplete."
            playbackState = .stopped
            return
        }

        /// Step 4: Select front camera channel
        ///
        /// ## Channel Selection Priority
        /// 1. Front camera (.front) - Default channel
        /// 2. First channel (channels.first) - If no front camera
        ///
        /// **Example:**
        /// ```swift
        /// videoFile.channels = [
        ///     ChannelInfo(position: .front, filePath: "/front.mp4"),
        ///     ChannelInfo(position: .rear, filePath: "/rear.mp4")
        /// ]
        ///
        /// channel(for: .front) → Select /front.mp4
        /// ```
        ///
        /// ## guard let
        /// - Safely extract with Optional Binding
        /// - Early return if nil
        guard let frontChannel = videoFile.channel(for: .front) ?? videoFile.channels.first else {
            errorMessage = "No video channel available"
            return
        }

        /// Step 5: Create VideoDecoder
        ///
        /// ## VideoDecoder
        /// - Video decoder wrapping FFmpeg
        /// - Open video file with filePath
        let decoder = VideoDecoder(filePath: frontChannel.filePath)

        /// Step 6: Initialize decoder (do-catch)
        ///
        /// ## try decoder.initialize()
        /// - Call FFmpeg avformat_open_input, avformat_find_stream_info
        /// - Parse video/audio stream information
        /// - Initialize codec
        ///
        /// ## On Error
        /// - Set errorMessage in catch block
        /// - playbackState = .stopped
        do {
            try decoder.initialize()
            self.decoder = decoder

            /// Step 7: Set duration
            ///
            /// ## duration Priority
            /// 1. decoder.getDuration() - Value from FFmpeg directly (accurate)
            /// 2. videoFile.duration - Value from file info (fallback)
            if let videoDuration = decoder.getDuration() {
                self.duration = videoDuration
            } else {
                self.duration = videoFile.duration
            }

            /// Step 8: Get frame rate
            ///
            /// ## videoInfo
            /// - Video stream information (resolution, frame rate, codec, etc.)
            /// - Store in targetFrameRate for Timer interval calculation
            if let videoInfo = decoder.videoInfo {
                self.targetFrameRate = videoInfo.frameRate
            }

            /// Step 9: Load first frame
            ///
            /// ## loadFrameAt(time: 0)
            /// - Decode frame at time: 0 seconds
            /// - Assign to currentFrame → Display in View
            loadFrameAt(time: 0)

            /// Step 10: Initialize AudioPlayer
            ///
            /// ## decoder.audioInfo
            /// - Audio stream information (sample rate, channel count, codec, etc.)
            /// - nil means no audio (video only playback)
            ///
            /// **Initialization Process:**
            /// ```
            /// Create AudioPlayer()
            ///      ↓
            /// audioPlayer.start() → Prepare audio playback
            ///      ↓
            /// audioPlayer.setVolume(volume) → Set volume
            ///      ↓
            /// self.audioPlayer = audioPlayer (Store)
            /// ```
            ///
            /// ## Failure Handling
            /// - Print warning message
            /// - audioPlayer = nil (Continue video-only playback)
            if decoder.audioInfo != nil {
                let audioPlayer = AudioPlayer()
                do {
                    try audioPlayer.start()
                    audioPlayer.setVolume(Float(volume))
                    self.audioPlayer = audioPlayer
                } catch {
                    print("Warning: Failed to start audio player: \(error.localizedDescription)")
                    // Continue without audio
                }
            }

            /// Step 11: Update state
            playbackState = .paused  // Ready to play (paused state)
            errorMessage = nil       // Clear error message

        } catch {
            /// Error handling
            ///
            /// ## catch Block
            /// - Executed when decoder.initialize() fails
            /// - Store error details in errorMessage
            /// - playbackState = .stopped
            ///
            /// **Error Examples:**
            /// ```
            /// "Failed to load video: File not found"
            /// "Failed to load video: Unsupported codec"
            /// "Failed to load video: Permission denied"
            /// ```
            errorMessage = "Failed to load video: \(error.localizedDescription)"
            playbackState = .stopped
        }
    }

    /// Start or resume playback
    ///
    /// ## Operation Conditions
    /// - playbackState != .playing (not already playing)
    /// - decoder != nil (video loaded)
    ///
    /// ## Operation
    /// 1. playbackState = .playing
    /// 2. audioPlayer.resume() → Start audio playback
    /// 3. startPlaybackTimer() → Start timer (play frame by frame)
    ///
    /// **Usage Examples:**
    /// ```swift
    /// // Play after loading
    /// viewModel.loadVideo(videoFile)
    /// viewModel.play()  // Start playback
    ///
    /// // Resume after pause
    /// viewModel.pause()
    /// viewModel.play()  // Resume playback
    /// ```
    func play() {
        /// Check guard conditions
        ///
        /// ## playbackState != .playing
        /// - Don't execute if already playing (prevent duplication)
        ///
        /// ## decoder != nil
        /// - Don't execute if video not loaded
        guard playbackState != .playing, decoder != nil else { return }

        playbackState = .playing
        audioPlayer?.resume()  // Resume audio playback (if was paused)
        startPlaybackTimer()   // Start Timer → Play frame by frame
    }

    /// Pause playback
    ///
    /// ## Operation Conditions
    /// - playbackState == .playing (only when playing)
    ///
    /// ## Operation
    /// 1. playbackState = .paused
    /// 2. audioPlayer.pause() → Pause audio
    /// 3. stopPlaybackTimer() → Stop timer
    ///
    /// ## State Preservation
    /// - Preserve currentTime, playbackPosition, currentFrame
    /// - Resume from current position when play() is called
    ///
    /// **Usage Example:**
    /// ```swift
    /// viewModel.play()   // Start playback
    /// // ... playing ...
    /// viewModel.pause()  // Pause
    /// // currentTime = 5.0 (preserved)
    /// viewModel.play()   // Resume from 5.0 seconds
    /// ```
    func pause() {
        guard playbackState == .playing else { return }

        playbackState = .paused
        audioPlayer?.pause()  // Pause audio (keep buffer)
        stopPlaybackTimer()   // Stop Timer
    }

    /// Toggle play/pause
    ///
    /// ## Toggle Operation
    /// - .playing → Call pause()
    /// - .paused or .stopped → Call play()
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Implement Play/Pause button
    /// Button(action: {
    ///     viewModel.togglePlayPause()
    /// }) {
    ///     Image(systemName: viewModel.playbackState == .playing ? "pause.fill" : "play.fill")
    /// }
    /// ```
    func togglePlayPause() {
        if playbackState == .playing {
            pause()
        } else {
            play()
        }
    }

    /// Stop playback and release resources
    ///
    /// ## Stop Process
    /// ```
    /// 1. stopPlaybackTimer() → Stop and release Timer
    ///      ↓
    /// 2. audioPlayer.stop() → Stop audio and clear buffer
    ///      ↓
    /// 3. audioPlayer = nil → Release AudioPlayer
    ///      ↓
    /// 4. frameCache.removeAll() → Clean frame cache
    ///      ↓
    /// 5. Reset state (playbackState, currentTime, playbackPosition, currentFrame)
    ///      ↓
    /// 6. decoder = nil → Release VideoDecoder (clean up FFmpeg resources)
    ///      ↓
    /// 7. videoFile = nil → Release file information
    /// ```
    ///
    /// ## Why Clean Cache
    /// - Cache unnecessary when video is stopped
    /// - Release memory (up to 250MB)
    /// - Start with clean state when loading another video
    ///
    /// ## When to Use
    /// - User clicks stop button
    /// - Load another video (beginning of loadVideo)
    /// - End of file (EOF) reached
    /// - ViewModel deallocated (deinit)
    ///
    /// **Usage Example:**
    /// ```swift
    /// viewModel.play()  // Playing
    /// viewModel.stop()  // Stop → Release all resources
    ///
    /// // Check state
    /// viewModel.playbackState  // .stopped
    /// viewModel.currentTime    // 0.0
    /// viewModel.currentFrame   // nil
    /// ```
    func stop() {
        stopPlaybackTimer()       // Stop Timer
        audioPlayer?.stop()       // Stop audio
        audioPlayer = nil         // Release AudioPlayer
        frameCache.removeAll()    // Clean frame cache (release memory)
        playbackState = .stopped  // State: stopped
        currentTime = 0.0         // Reset time
        playbackPosition = 0.0    // Reset position
        currentFrame = nil        // Reset frame
        decoder = nil             // Release VideoDecoder (clean FFmpeg)
        videoFile = nil           // Release file info
    }

    /// Seek to specific position (ratio-based)
    ///
    /// ## Seek Algorithm
    /// ```
    /// 1. Clamp position to 0.0~1.0
    ///      ↓
    /// 2. Calculate targetTime = position * duration
    ///      ↓
    /// 3. Call seekToTime(targetTime)
    /// ```
    ///
    /// - Parameter position: Seek position (0.0 = start, 1.0 = end)
    ///
    /// **Usage Examples:**
    /// ```swift
    /// // duration = 90 seconds
    /// viewModel.seek(to: 0.0)   → seekToTime(0 sec)   (start)
    /// viewModel.seek(to: 0.5)   → seekToTime(45 sec)  (middle)
    /// viewModel.seek(to: 1.0)   → seekToTime(90 sec)  (end)
    /// viewModel.seek(to: 1.5)   → seekToTime(90 sec)  (clamp)
    /// viewModel.seek(to: -0.1)  → seekToTime(0 sec)   (clamp)
    /// ```
    ///
    /// **Usage in View (Timeline Slider):**
    /// ```swift
    /// Slider(value: $viewModel.playbackPosition, in: 0...1)
    ///     .onChange(of: playbackPosition) { newPosition in
    ///         viewModel.seek(to: newPosition)
    ///     }
    /// ```
    func seek(to position: Double) {
        /// Limit position to 0.0~1.0 range
        ///
        /// ## max(0.0, min(1.0, position))
        /// - position < 0.0 → 0.0
        /// - position > 1.0 → 1.0
        /// - 0.0 <= position <= 1.0 → position (as is)
        let clampedPosition = max(0.0, min(1.0, position))

        /// Calculate targetTime
        ///
        /// ## Convert position to actual time
        /// ```
        /// duration = 90 seconds, position = 0.5
        /// targetTime = 0.5 * 90 = 45 seconds
        /// ```
        let targetTime = clampedPosition * duration

        /// Perform actual seek
        seekToTime(targetTime)
    }

    /// Seek to specific time (in seconds)
    ///
    /// ## Seek Process
    /// ```
    /// 1. Clamp time to 0~duration range
    ///      ↓
    /// 2. Invalidate frameCache (remove all cache)
    ///      ↓
    /// 3. decoder.seek(to: time) → Execute FFmpeg seek
    ///      ↓
    /// 4. Update currentTime, playbackPosition
    ///      ↓
    /// 5. audioPlayer.flush() → Clear audio buffer
    ///      ↓
    /// 6. loadFrameAt(time:) → Load frame at that time
    /// ```
    ///
    /// ## Why Invalidate Cache
    /// - Seek moves to distant position
    /// - Previously cached frames are no longer useful
    /// - Re-cache frames around new position
    ///
    /// **Example:**
    /// ```
    /// currentTime = 10 sec (cache: 5~15 sec frames)
    /// Call seekToTime(50 sec)
    ///      ↓
    /// Invalidate cache (remove 5~15 sec frames)
    ///      ↓
    /// Move to 50 sec
    ///      ↓
    /// Create new cache (45~55 sec frames)
    /// ```
    ///
    /// - Parameter time: Time to seek (seconds)
    ///
    /// **Usage Examples:**
    /// ```swift
    /// // duration = 90 seconds
    /// viewModel.seekToTime(0.0)    → Move to start
    /// viewModel.seekToTime(45.0)   → Move to 45 sec
    /// viewModel.seekToTime(90.0)   → Move to end
    /// viewModel.seekToTime(100.0)  → Clamp to 90 sec (end)
    /// viewModel.seekToTime(-5.0)   → Clamp to 0 sec (start)
    /// ```
    func seekToTime(_ time: TimeInterval) {
        guard let decoder = decoder else { return }

        /// Limit time to 0~duration range
        ///
        /// ## max(0.0, min(duration, time))
        /// - time < 0.0 → 0.0 (start)
        /// - time > duration → duration (end)
        /// - 0.0 <= time <= duration → time (as is)
        let clampedTime = max(0.0, min(duration, time))

        /// Invalidate cache
        ///
        /// ## frameCache.removeAll()
        /// - Remove all cached frames
        /// - Immediately release memory (ARC)
        ///
        /// **Why Invalidate:**
        /// - Seek often moves to distant positions
        /// - Existing cache is no longer valid
        /// - More efficient to re-cache frames around new position
        ///
        /// **Exception:**
        /// - stepForward/stepBackward call seekToTime but for short distances
        /// - Cache still invalidated, but immediately re-cached in loadFrameAt
        /// - No big loss (just 1 frame decoding)
        frameCache.removeAll()

        /// Perform seek (do-catch)
        do {
            /// 1. Execute FFmpeg seek
            ///
            /// ## decoder.seek(to: clampedTime)
            /// - Call av_seek_frame()
            /// - Move to keyframe at that time
            /// - Initialize decoder internal buffer
            try decoder.seek(to: clampedTime)

            /// 2. Update state
            currentTime = clampedTime
            playbackPosition = duration > 0 ? clampedTime / duration : 0.0

            /// 3. Clear audio buffer
            ///
            /// ## audioPlayer.flush()
            /// - Remove audio frames waiting to play
            /// - Prevent old audio from playing after seek
            audioPlayer?.flush()

            /// 4. Load frame at that time
            ///
            /// ## loadFrameAt(time: clampedTime)
            /// - Decode video frame at seek position
            /// - Update currentFrame → Display in View
            loadFrameAt(time: clampedTime)

        } catch {
            /// Handle seek failure
            ///
            /// **Failure Examples:**
            /// - Corrupted video file
            /// - Invalid timestamp
            /// - FFmpeg internal error
            errorMessage = "Seek failed: \(error.localizedDescription)"
        }
    }

    /// Move forward one frame
    ///
    /// ## Frame-by-Frame Movement
    /// - Calculate frameTime = 1.0 / targetFrameRate
    /// - Call seekToTime(currentTime + frameTime)
    ///
    /// **Calculation Example:**
    /// ```swift
    /// targetFrameRate = 30.0
    /// frameTime = 1.0 / 30.0 = 0.0333 seconds (approx 33ms)
    ///
    /// currentTime = 5.0 seconds
    /// stepForward() → seekToTime(5.0333 sec) → Next frame
    /// ```
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Frame-by-frame button
    /// Button(action: { viewModel.stepForward() }) {
    ///     Image(systemName: "forward.frame")  // ▶| icon
    /// }
    /// ```
    func stepForward() {
        let frameTime = 1.0 / targetFrameRate
        seekToTime(currentTime + frameTime)
    }

    /// Move backward one frame
    ///
    /// ## Frame-by-Frame Movement
    /// - Calculate frameTime = 1.0 / targetFrameRate
    /// - Call seekToTime(currentTime - frameTime)
    ///
    /// **Calculation Example:**
    /// ```swift
    /// targetFrameRate = 30.0
    /// frameTime = 1.0 / 30.0 = 0.0333 seconds (approx 33ms)
    ///
    /// currentTime = 5.0 seconds
    /// stepBackward() → seekToTime(4.9667 sec) → Previous frame
    /// ```
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Frame-by-frame button
    /// Button(action: { viewModel.stepBackward() }) {
    ///     Image(systemName: "backward.frame")  // |◀ icon
    /// }
    /// ```
    func stepBackward() {
        let frameTime = 1.0 / targetFrameRate
        seekToTime(currentTime - frameTime)
    }

    /// Set playback speed
    ///
    /// ## Speed Range
    /// - Minimum: 0.1x (10x slower)
    /// - Maximum: 4.0x (4x faster)
    ///
    /// ## Speed Change Operation
    /// 1. Clamp speed to 0.1~4.0
    /// 2. Store in playbackSpeed
    /// 3. Restart Timer if playing (apply new interval)
    ///
    /// - Parameter speed: Playback speed (0.5x, 1.0x, 2.0x, etc.)
    ///
    /// **Usage Examples:**
    /// ```swift
    /// viewModel.setPlaybackSpeed(0.5)  // 0.5x speed (slower)
    /// viewModel.setPlaybackSpeed(1.0)  // Normal speed
    /// viewModel.setPlaybackSpeed(2.0)  // 2x speed (faster)
    /// viewModel.setPlaybackSpeed(5.0)  // Clamp to 4.0 (max)
    /// ```
    func setPlaybackSpeed(_ speed: Double) {
        /// Limit speed to 0.1~4.0 range
        playbackSpeed = max(0.1, min(4.0, speed))

        /// Restart Timer if playing
        ///
        /// ## Recalculate Timer Interval
        /// ```
        /// // Before: speed = 1.0x, interval = 0.0333 sec
        /// // After: speed = 2.0x, interval = 0.0167 sec (2x faster)
        /// ```
        ///
        /// **Operation:**
        /// ```
        /// stopPlaybackTimer() → Stop existing Timer
        ///      ↓
        /// startPlaybackTimer() → Start Timer with new interval
        /// ```
        if playbackState == .playing {
            stopPlaybackTimer()
            startPlaybackTimer()
        }
    }

    /// Set volume
    ///
    /// ## Volume Range
    /// - Minimum: 0.0 (mute)
    /// - Maximum: 1.0 (max volume)
    ///
    /// ## Volume Change Operation
    /// 1. Clamp volume to 0.0~1.0
    /// 2. Store in self.volume
    /// 3. Call audioPlayer.setVolume()
    ///
    /// - Parameter volume: Volume (0.0 ~ 1.0)
    ///
    /// **Usage Examples:**
    /// ```swift
    /// viewModel.setVolume(0.0)   // Mute
    /// viewModel.setVolume(0.5)   // 50% volume
    /// viewModel.setVolume(1.0)   // Max volume
    /// viewModel.setVolume(1.5)   // Clamp to 1.0 (max)
    /// ```
    func setVolume(_ volume: Double) {
        /// Limit volume to 0.0~1.0 range
        self.volume = max(0.0, min(1.0, volume))

        /// Pass volume to AudioPlayer
        ///
        /// ## Float Conversion
        /// - AudioPlayer uses Float type
        /// - Double → Float casting required
        audioPlayer?.setVolume(Float(self.volume))
    }

    /// Seek by relative time amount
    ///
    /// ## Relative Seek
    /// - Move forward/backward from current time
    /// - seconds > 0: Forward
    /// - seconds < 0: Backward
    ///
    /// - Parameter seconds: Time to move (seconds, positive=forward, negative=backward)
    ///
    /// **Usage Examples:**
    /// ```swift
    /// // currentTime = 30 seconds
    /// viewModel.seekBySeconds(10)   → seekToTime(40 sec)  (10 sec forward)
    /// viewModel.seekBySeconds(-5)   → seekToTime(35 sec)  (5 sec backward)
    /// viewModel.seekBySeconds(100)  → seekToTime(90 sec)  (clamp to duration)
    /// ```
    ///
    /// **Usage in View (Keyboard Shortcuts):**
    /// ```swift
    /// .onKeyPress(.rightArrow) { viewModel.seekBySeconds(5) }   // → 5 sec forward
    /// .onKeyPress(.leftArrow) { viewModel.seekBySeconds(-5) }   // ← 5 sec backward
    /// ```
    func seekBySeconds(_ seconds: Double) {
        seekToTime(currentTime + seconds)
    }

    /// Adjust volume (relative value)
    ///
    /// ## Relative Volume Adjustment
    /// - Increase/decrease from current volume
    /// - delta > 0: Increase
    /// - delta < 0: Decrease
    ///
    /// - Parameter delta: Volume change amount (-1.0 ~ 1.0)
    ///
    /// **Usage Examples:**
    /// ```swift
    /// // volume = 0.5
    /// viewModel.adjustVolume(by: 0.1)   → setVolume(0.6)  (10% increase)
    /// viewModel.adjustVolume(by: -0.2)  → setVolume(0.4)  (20% decrease)
    /// viewModel.adjustVolume(by: 0.8)   → setVolume(1.0)  (clamp to max)
    /// ```
    ///
    /// **Usage in View (Keyboard Shortcuts):**
    /// ```swift
    /// .onKeyPress(.upArrow) { viewModel.adjustVolume(by: 0.1) }     // ↑ Increase volume
    /// .onKeyPress(.downArrow) { viewModel.adjustVolume(by: -0.1) }  // ↓ Decrease volume
    /// ```
    func adjustVolume(by delta: Double) {
        setVolume(volume + delta)
    }

    // MARK: - Snapshot Methods

    /// Capture current frame as NSImage
    ///
    /// ## Snapshot Capture
    /// - Convert currently displayed video frame to image
    /// - CGImage → NSImage conversion
    ///
    /// - Returns: NSImage, nil if capture fails
    ///
    /// **Usage Example:**
    /// ```swift
    /// if let snapshot = viewModel.captureCurrentFrame() {
    ///     // Save or display image
    ///     saveImage(snapshot, to: url)
    /// }
    /// ```
    func captureCurrentFrame() -> NSImage? {
        // Return nil if no currentFrame
        guard let frame = currentFrame else {
            return nil
        }

        // VideoFrame → CGImage conversion
        guard let cgImage = frame.toCGImage() else {
            return nil
        }

        // CGImage → NSImage conversion
        let size = NSSize(width: frame.width, height: frame.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    // MARK: - Segment Selection Methods

    /// Set current time as In Point
    ///
    /// ## In Point Setting
    /// - Save current playback position as segment start point
    /// - Remove outPoint if already set and earlier than currentTime
    ///
    /// **Usage Example:**
    /// ```swift
    /// // currentTime = 5.0
    /// viewModel.setInPoint()
    /// // inPoint = 5.0
    ///
    /// // Button implementation
    /// Button("Set In") {
    ///     viewModel.setInPoint()
    /// }
    /// ```
    func setInPoint() {
        inPoint = currentTime

        // Remove Out Point if it's before In Point
        if let out = outPoint, out <= currentTime {
            outPoint = nil
        }
    }

    /// Set current time as Out Point
    ///
    /// ## Out Point Setting
    /// - Save current playback position as segment end point
    /// - Cannot set if inPoint not set or currentTime is earlier
    ///
    /// **Usage Example:**
    /// ```swift
    /// // currentTime = 15.0, inPoint = 5.0
    /// viewModel.setOutPoint()
    /// // outPoint = 15.0
    ///
    /// // Button implementation
    /// Button("Set Out") {
    ///     viewModel.setOutPoint()
    /// }
    /// ```
    func setOutPoint() {
        // Only set if In Point is set and current time is after it
        guard let inTime = inPoint, currentTime > inTime else {
            return
        }

        outPoint = currentTime
    }

    /// Remove In Point
    ///
    /// ## Reset
    /// - Reset inPoint to nil
    /// - Also remove outPoint (segment becomes invalid)
    ///
    /// **Usage Example:**
    /// ```swift
    /// viewModel.clearInPoint()
    /// // inPoint = nil, outPoint = nil
    /// ```
    func clearInPoint() {
        inPoint = nil
        outPoint = nil  // Also remove Out Point
    }

    /// Remove Out Point
    ///
    /// ## Reset
    /// - Reset outPoint to nil
    /// - Keep inPoint (can set Out Point again)
    ///
    /// **Usage Example:**
    /// ```swift
    /// viewModel.clearOutPoint()
    /// // outPoint = nil, inPoint is kept
    /// ```
    func clearOutPoint() {
        outPoint = nil
    }

    /// Reset selected segment
    ///
    /// ## Full Reset
    /// - Reset both inPoint and outPoint to nil
    ///
    /// **Usage Example:**
    /// ```swift
    /// viewModel.clearSegment()
    /// // inPoint = nil, outPoint = nil
    ///
    /// // Button implementation
    /// Button("Clear") {
    ///     viewModel.clearSegment()
    /// }
    /// ```
    func clearSegment() {
        inPoint = nil
        outPoint = nil
    }

    /// Check if selected segment is valid
    ///
    /// ## Validation
    /// - Both inPoint and outPoint are set
    /// - outPoint > inPoint (segment length > 0)
    ///
    /// - Returns: true if segment is valid
    ///
    /// **Usage Example:**
    /// ```swift
    /// if viewModel.hasValidSegment {
    ///     // Enable Export button
    /// }
    /// ```
    var hasValidSegment: Bool {
        guard let inTime = inPoint, let outTime = outPoint else {
            return false
        }
        return outTime > inTime
    }

    /// Selected segment length (seconds)
    ///
    /// ## Segment Length Calculation
    /// - segmentDuration = outPoint - inPoint
    /// - Return 0.0 if invalid
    ///
    /// - Returns: Segment length (seconds)
    ///
    /// **Usage Example:**
    /// ```swift
    /// // inPoint = 5.0, outPoint = 15.0
    /// viewModel.segmentDuration  // 10.0
    ///
    /// // UI display
    /// Text("Segment: \(formatTime(viewModel.segmentDuration))")
    /// // "Segment: 00:10"
    /// ```
    var segmentDuration: TimeInterval {
        guard let inTime = inPoint, let outTime = outPoint else {
            return 0.0
        }
        return outTime - inTime
    }

    // MARK: - Private Methods

    /// Start playback timer
    ///
    /// ## Create and Start Timer
    /// ```
    /// 1. Stop existing Timer (stopPlaybackTimer)
    ///      ↓
    /// 2. Calculate interval: (1.0 / targetFrameRate) / playbackSpeed
    ///      ↓
    /// 3. Create Timer.scheduledTimer (repeats: true)
    ///      ↓ Repeat execution at interval
    /// 4. Call updatePlayback() → Decode and display frames
    /// ```
    ///
    /// ## Interval Calculation Examples
    /// ```swift
    /// // 30 FPS, 1.0x speed
    /// targetFrameRate = 30.0, playbackSpeed = 1.0
    /// interval = (1.0 / 30.0) / 1.0 = 0.0333 seconds (33ms)
    ///
    /// // 30 FPS, 2.0x speed (2x faster)
    /// targetFrameRate = 30.0, playbackSpeed = 2.0
    /// interval = (1.0 / 30.0) / 2.0 = 0.0167 seconds (17ms)
    ///
    /// // 60 FPS, 0.5x speed (2x slower)
    /// targetFrameRate = 60.0, playbackSpeed = 0.5
    /// interval = (1.0 / 60.0) / 0.5 = 0.0333 seconds (33ms)
    /// ```
    private func startPlaybackTimer() {
        /// Clean up existing Timer
        stopPlaybackTimer()

        /// Calculate Timer interval
        ///
        /// ## (1.0 / targetFrameRate) / playbackSpeed
        /// - (1.0 / targetFrameRate): One frame time (seconds)
        /// - / playbackSpeed: Apply playback speed
        let interval = (1.0 / targetFrameRate) / playbackSpeed

        /// Create and start Timer
        ///
        /// ## Timer.scheduledTimer
        /// - withTimeInterval: Execute every interval seconds
        /// - repeats: true → Keep repeating (false for one-time execution)
        /// - [weak self]: Prevent retain cycle (prevent memory leak)
        ///
        /// **Why weak self is needed:**
        /// ```
        /// Timer → closure → self (ViewModel)
        ///   ↑__________________________|
        /// Retain cycle occurs! (Memory not released)
        ///
        /// Solved with [weak self]:
        /// Timer → closure --weak--> self
        /// (Timer release → closure release → self can be released)
        /// ```
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    /// Stop playback timer
    ///
    /// ## Clean up Timer
    /// ```
    /// 1. playbackTimer?.invalidate() → Stop and release Timer
    ///      ↓
    /// 2. playbackTimer = nil → Remove reference
    /// ```
    ///
    /// ## invalidate()
    /// - Remove Timer from RunLoop
    /// - Closure no longer called
    /// - Release Timer memory
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    /// Update playback (Timer callback)
    ///
    /// ## Invocation Point
    /// - Called periodically by playbackTimer (based on frame rate + playback speed)
    ///
    /// ## Update Process
    /// ```
    /// 1. decoder.decodeNextFrame() → Decode next frame
    ///      ↓
    /// 2. Process video frame
    ///    - Update currentFrame (@Published → View refreshes)
    ///    - Update currentTime
    ///    - Update playbackPosition
    ///      ↓
    /// 3. Process audio frame
    ///    - audioPlayer.enqueue(audioFrame) → Play audio
    ///      ↓
    /// 4. Check EOF
    ///    - Call stop() when end of file reached
    /// ```
    ///
    /// ## Error Handling
    /// - EOF error: Call stop(), set currentTime/playbackPosition to end
    /// - Other errors: Set errorMessage, call stop()
    private func updatePlayback() {
        /// Check decoder exists
        ///
        /// ## guard let
        /// - If decoder is nil, call stop() and return
        /// - Video is unloaded
        guard let decoder = decoder else {
            stop()
            return
        }

        /// Decode frame (do-catch)
        do {
            /// Decode next frame
            ///
            /// ## decoder.decodeNextFrame()
            /// - Calls FFmpeg av_read_frame(), avcodec_send_packet(), avcodec_receive_frame()
            /// - Returns: DecodeResult? (video: VideoFrame?, audio: AudioFrame?)
            /// - Returns nil: EOF (end of file)
            ///
            /// **Return Examples:**
            /// ```swift
            /// // Video + Audio
            /// DecodeResult(video: VideoFrame(...), audio: AudioFrame(...))
            ///
            /// // Video only
            /// DecodeResult(video: VideoFrame(...), audio: nil)
            ///
            /// // EOF
            /// nil
            /// ```
            if let result = try decoder.decodeNextFrame() {
                /// Process video frame
                if let videoFrame = result.video {
                    currentFrame = videoFrame  // @Published → View auto-refreshes
                    currentTime = videoFrame.timestamp
                    playbackPosition = duration > 0 ? currentTime / duration : 0.0
                }

                /// Process audio frame
                ///
                /// ## audioPlayer.enqueue(audioFrame)
                /// - Add audio frame to playback queue
                /// - AudioPlayer plays automatically
                ///
                /// ## Inner do-catch error
                /// - Only print warning message if audio playback fails
                /// - Continue video playback (without audio)
                if let audioFrame = result.audio {
                    do {
                        try audioPlayer?.enqueue(audioFrame)
                    } catch {
                        // Log audio error but continue video playback
                        print("Warning: Failed to enqueue audio frame: \(error.localizedDescription)")
                    }
                }
            } else {
                /// EOF (end of file) reached
                ///
                /// ## decodeNextFrame() returns nil
                /// - No more frames to decode
                /// - End playback
                stop()
                currentTime = duration        // Set to end time
                playbackPosition = 1.0        // 100% position
            }
        } catch {
            /// Handle decoding error
            ///
            /// ## DecoderError.endOfFile
            /// - EOF error (end of file)
            /// - Call stop(), set time/position to end
            ///
            /// ## Other errors
            /// - Decoding failure, corrupted frame, etc.
            /// - Set errorMessage, call stop()
            if case DecoderError.endOfFile = error {
                stop()
                currentTime = duration
                playbackPosition = 1.0
            } else {
                errorMessage = "Playback error: \(error.localizedDescription)"
                stop()
            }
        }
    }

    /// Load frame at specific time (with cache support)
    ///
    /// ## Usage Points
    /// - Display first frame after video load (loadVideo)
    /// - Display frame at position after seek (seekToTime)
    /// - Frame-by-frame movement (stepForward/stepBackward)
    ///
    /// ## Loading Process (with cache)
    /// ```
    /// 1. Calculate cacheKey(for: time) (round to 100ms units)
    ///      ↓
    /// 2. Query frameCache
    ///      ↓
    /// 3. Cache hit → Return immediately (skip decoding) ✅ Fast!
    /// ```
    ///
    /// ## Loading Process (without cache)
    /// ```
    /// 1. isBuffering = true (start loading)
    ///      ↓
    /// 2. decoder.seek(to: time) → FFmpeg seek
    ///      ↓
    /// 3. decoder.decodeNextFrame() → Decode frame
    ///      ↓
    /// 4. Update currentFrame (@Published → View refreshes)
    ///      ↓
    /// 5. addToCache(frame, at: cacheKey) → Save to cache
    ///      ↓
    /// 6. isBuffering = false (loading complete)
    /// ```
    ///
    /// ## Performance Improvement
    /// - Cache hit: 0ms decoding time (immediate return)
    /// - Cache miss: Decode + save to cache (fast next time)
    /// - Very useful for frame-by-frame movement (stepForward/stepBackward)
    ///
    /// - Parameter time: Time to load (seconds)
    private func loadFrameAt(time: TimeInterval) {
        guard let decoder = decoder else { return }

        /// Step 1: Query cache
        ///
        /// ## Calculate cacheKey
        /// - Round to 100ms units (0.1 second precision)
        /// - 1.234 sec → 1.2 sec
        /// - 1.278 sec → 1.3 sec
        let key = cacheKey(for: time)

        /// ## Check cache hit
        /// - Cache hit if frameCache[key] is not nil
        /// - Return immediately without decoding → Performance boost!
        if let cachedFrame = frameCache[key] {
            currentFrame = cachedFrame  // @Published → View refreshes
            return  // Skip decoding
        }

        /// Step 2: Cache miss - perform decoding
        ///
        /// ## isBuffering = true
        /// - @Published → Display loading indicator in View
        isBuffering = true

        /// Load frame (do-catch)
        do {
            /// 3. Seek to that time
            try decoder.seek(to: time)

            /// 4. Decode frame
            ///
            /// ## Nested if let
            /// - Execute only when result is not nil
            /// - AND result.video is not nil
            ///
            /// **Condition Check:**
            /// ```swift
            /// result = nil               → Does not execute (EOF)
            /// result = DecodeResult(video: nil, ...) → Does not execute (no video)
            /// result = DecodeResult(video: VideoFrame(...), ...) → Executes ✅
            /// ```
            if let result = try decoder.decodeNextFrame(),
               let videoFrame = result.video {
                currentFrame = videoFrame  // @Published → View refreshes

                /// 5. Save to cache
                ///
                /// ## addToCache
                /// - Save decoded frame to cache
                /// - Return quickly on next access to same time
                /// - Automatically remove old entries using LRU method
                addToCache(frame: videoFrame, at: key)
            }

            /// Buffering complete
            isBuffering = false
        } catch {
            /// Handle load failure
            errorMessage = "Failed to load frame: \(error.localizedDescription)"
            isBuffering = false
        }
    }

    /// Calculate cache key (round to 100ms units)
    ///
    /// ## Rounding Algorithm
    /// ```
    /// 1. time * 10.0 (0.1 sec → 1.0)
    ///      ↓
    /// 2. round() (round)
    ///      ↓
    /// 3. / 10.0 (back to seconds)
    /// ```
    ///
    /// ## Examples
    /// ```swift
    /// cacheKey(for: 1.234) → 1.2
    /// cacheKey(for: 1.278) → 1.3
    /// cacheKey(for: 1.000) → 1.0
    /// cacheKey(for: 5.555) → 5.6
    /// ```
    ///
    /// ## Why 100ms Precision
    /// - 30fps video: Frame interval 33ms → 100ms covers 3 frames
    /// - 60fps video: Frame interval 17ms → 100ms covers 6 frames
    /// - Too small: Increased cache misses (memory waste)
    /// - Too large: Reduced time accuracy
    ///
    /// - Parameter time: Original time (seconds)
    /// - Returns: Time rounded to 100ms units
    private func cacheKey(for time: TimeInterval) -> TimeInterval {
        return round(time * 10.0) / 10.0
    }

    /// Add frame to cache (LRU method)
    ///
    /// ## Cache Addition Process
    /// ```
    /// 1. Add frame to frameCache
    ///      ↓
    /// 2. Check cache size
    ///      ↓ frameCache.count > maxFrameCacheSize
    /// 3. Remove old entries (LRU)
    ///      ↓
    /// 4. Periodic cache cleanup (every 5 seconds)
    /// ```
    ///
    /// ## LRU (Least Recently Used)
    /// - Remove least recently used entries
    /// - Keep recently used frames
    /// - Maintain frames in frequently accessed areas
    ///
    /// - Parameter frame: Video frame to save
    /// - Parameter key: Cache key (time in 100ms units)
    private func addToCache(frame: VideoFrame, at key: TimeInterval) {
        /// 1. Add to cache
        frameCache[key] = frame

        /// 2. Cleanup if cache size exceeded
        ///
        /// ## Check maxFrameCacheSize exceeded
        /// - Remove oldest entry when exceeds 30
        /// - Limit memory usage
        if frameCache.count > maxFrameCacheSize {
            /// LRU removal
            ///
            /// ## Removal Algorithm
            /// 1. Sort all keys (time order)
            /// 2. Remove first key (oldest time)
            ///
            /// **Example:**
            /// ```
            /// frameCache.keys = [1.0, 5.0, 3.0, 8.0, ...]
            /// sorted() → [1.0, 3.0, 5.0, 8.0, ...]
            /// first → 1.0 (oldest time)
            /// remove(1.0) → Remove that frame
            /// ```
            if let oldestKey = frameCache.keys.sorted().first {
                frameCache.removeValue(forKey: oldestKey)
            }
        }

        /// 3. Periodic cache cleanup (every 5 seconds)
        ///
        /// ## Purpose of Periodic Cleanup
        /// - Relieve memory pressure
        /// - Remove old frames no longer needed
        /// - Remove frames far from current playback position
        let now = Date()
        if now.timeIntervalSince(lastCacheCleanupTime) > 5.0 {
            cleanupCache()
            lastCacheCleanupTime = now
        }
    }

    /// Cleanup cache (remove old entries)
    ///
    /// ## Cleanup Algorithm
    /// ```
    /// 1. Set range based on current playback time
    ///      ↓
    /// 2. Remove frames outside currentTime ± 5 second range
    ///      ↓ Example: currentTime = 10 seconds
    /// 3. Keep only frames in 5 ~ 15 second range
    ///      ↓
    /// 4. Remove the rest (free memory)
    /// ```
    ///
    /// ## Reason for Range Selection
    /// - ±5 seconds: Sufficient range for frame-by-frame movement
    /// - Approximately 150 frames for 30fps
    /// - Memory usage: approximately 1.2GB (1080p RGBA basis)
    ///
    /// ## Invocation Points
    /// - Called automatically every 5 seconds from addToCache()
    /// - Not called when entire cache is removed in seekToTime()
    private func cleanupCache() {
        /// Set range based on current time
        ///
        /// ## Retention range: currentTime ± 5 seconds
        /// - lowerBound = currentTime - 5.0
        /// - upperBound = currentTime + 5.0
        let lowerBound = currentTime - 5.0
        let upperBound = currentTime + 5.0

        /// Find keys outside range
        ///
        /// ## filter
        /// - Condition: key < lowerBound || key > upperBound
        /// - Result: Array of keys to remove
        let keysToRemove = frameCache.keys.filter { key in
            key < lowerBound || key > upperBound
        }

        /// Remove frames outside range
        ///
        /// ## removeValue(forKey:)
        /// - Remove key-value pair from Dictionary
        /// - VideoFrame memory automatically released (ARC)
        for key in keysToRemove {
            frameCache.removeValue(forKey: key)
        }
    }

    /// Handle memory warning
    ///
    /// ## Memory Warning Response
    /// ```
    /// System low on memory
    ///      ↓
    /// Send NSApplicationDidReceiveMemoryWarningNotification
    ///      ↓
    /// Call handleMemoryWarning()
    ///      ↓
    /// Remove entire frame cache (free up to 250MB)
    ///      ↓
    /// Relieve memory pressure
    /// ```
    ///
    /// ## Memory Freed
    /// - Frame cache: Maximum 30 frames
    /// - 1080p RGBA basis: Approximately 250MB
    /// - 4K RGBA basis: Approximately 1GB
    ///
    /// ## What is Not Removed
    /// - currentFrame (currently displayed frame is kept)
    /// - decoder, audioPlayer (playback can continue)
    ///
    /// ## Impact
    /// - Reduced cache hit rate (temporary)
    /// - Slightly slower frame-by-frame movement (temporary)
    /// - Playback itself operates normally (re-caches)
    ///
    /// ## Invocation Points
    /// - Registered with NotificationCenter in init()
    /// - Called automatically when system detects low memory
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Not called directly by user
    /// // Called automatically by system
    /// ```
    private func handleMemoryWarning() {
        /// Remove entire frame cache
        ///
        /// ## removeAll()
        /// - Remove all items from Dictionary
        /// - VideoFrame memory released immediately (ARC)
        /// - Free up to 250MB (1080p) ~ 1GB (4K)
        ///
        /// **Memory Release Calculation:**
        /// ```
        /// 1080p RGBA frame = 1920 × 1080 × 4 bytes = 8.3MB
        /// Cache 30 frames = 8.3MB × 30 = 249MB
        ///
        /// 4K RGBA frame = 3840 × 2160 × 4 bytes = 33MB
        /// Cache 30 frames = 33MB × 30 = 990MB
        /// ```
        frameCache.removeAll()

        /// Debug log
        ///
        /// ## print
        /// - For checking memory warning occurrence during development
        /// - Consider removing in release build
        print("Memory warning received: Frame cache cleared")
    }
}

// MARK: - Supporting Types

/// @enum PlaybackState
/// @brief Playback state enumeration
/// @details Represents the playback state of the video player.
///
/// ## State Types
/// - .stopped: Stopped state (no video or playback ended)
/// - .playing: Playing (Timer running)
/// - .paused: Paused (state maintained)
///
/// ## Equatable
/// - Can be compared with == operator
/// - Can check state in if statements
///
/// **State Transition Diagram:**
/// ```
///          loadVideo()
///  .stopped ────────────> .paused
///     ↑                      ↓ play()
///     |                   .playing
///     |                      ↓ pause()
///     └────── stop() ────── .paused
/// ```
///
/// **Usage Examples:**
/// ```swift
/// if viewModel.playbackState == .playing {
///     print("Playing")
/// }
///
/// switch viewModel.playbackState {
/// case .stopped:
///     print("Stopped")
/// case .playing:
///     print("Playing")
/// case .paused:
///     print("Paused")
/// }
/// ```
enum PlaybackState: Equatable {
    /// Stopped state
    ///
    /// ## Entry Points
    /// - Initial state (before video load)
    /// - After stop() called
    /// - After EOF reached
    /// - After loading failure
    case stopped

    /// Playing
    ///
    /// ## Entry Points
    /// - After play() called
    /// - When togglePlayPause() called (paused → playing)
    ///
    /// ## Characteristics
    /// - Timer running (updatePlayback called repeatedly)
    /// - AudioPlayer playing
    case playing

    /// Paused
    ///
    /// ## Entry Points
    /// - After loadVideo() completes (ready to play)
    /// - After pause() called
    /// - When togglePlayPause() called (playing → paused)
    ///
    /// ## Characteristics
    /// - Timer stopped
    /// - AudioPlayer paused
    /// - currentTime, playbackPosition, currentFrame preserved
    case paused

    /// State display name
    ///
    /// ## displayName
    /// - Returns string to display in UI
    ///
    /// **Examples:**
    /// ```swift
    /// PlaybackState.stopped.displayName  // "Stopped"
    /// PlaybackState.playing.displayName  // "Playing"
    /// PlaybackState.paused.displayName   // "Paused"
    /// ```
    var displayName: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        }
    }
}

// MARK: - Computed Properties

/// VideoPlayerViewModel Extension - Time Formatting Computed Properties
///
/// ## Extension
/// - Add functionality to existing class
/// - Add methods/properties without modifying original code
///
/// **Purpose of this Extension:**
/// - Convert time (TimeInterval) to "MM:SS" format string
/// - Provide strings directly usable in View
extension VideoPlayerViewModel {
    /// Current time formatted string (MM:SS)
    ///
    /// ## Format Examples
    /// ```swift
    /// currentTime = 0.0    → "00:00"
    /// currentTime = 5.5    → "00:05"
    /// currentTime = 65.0   → "01:05"
    /// currentTime = 125.0  → "02:05"
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Text(viewModel.currentTimeString)  // "02:05"
    /// ```
    var currentTimeString: String {
        return formatTime(currentTime)
    }

    /// Total playback time formatted string (MM:SS)
    ///
    /// ## Format Examples
    /// ```swift
    /// duration = 90.0   → "01:30"
    /// duration = 600.0  → "10:00"
    /// duration = 3665.0 → "61:05" (1 hour 1 minute 5 seconds)
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Text("\(viewModel.currentTimeString) / \(viewModel.durationString)")
    /// // "02:05 / 10:00"
    /// ```
    var durationString: String {
        return formatTime(duration)
    }

    /// Remaining time formatted string (-MM:SS)
    ///
    /// ## Calculation
    /// - remaining = duration - currentTime
    /// - Prevent negative: max(0, remaining)
    /// - Add "-" prefix
    ///
    /// **Format Examples:**
    /// ```swift
    /// duration = 90 sec, currentTime = 30 sec
    /// remaining = 90 - 30 = 60 sec
    /// → "-01:00"
    ///
    /// duration = 90 sec, currentTime = 85 sec
    /// remaining = 90 - 85 = 5 sec
    /// → "-00:05"
    ///
    /// duration = 90 sec, currentTime = 90 sec
    /// remaining = 90 - 90 = 0 sec
    /// → "-00:00"
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Text(viewModel.remainingTimeString)  // "-01:00" (remaining time)
    /// ```
    var remainingTimeString: String {
        let remaining = max(0, duration - currentTime)
        return "-\(formatTime(remaining))"
    }

    /// Playback speed formatted string (e.g., "1.0x")
    ///
    /// ## Format
    /// - String(format: "%.1fx", playbackSpeed)
    /// - 1 decimal place + "x" suffix
    ///
    /// **Format Examples:**
    /// ```swift
    /// playbackSpeed = 0.5  → "0.5x"
    /// playbackSpeed = 1.0  → "1.0x"
    /// playbackSpeed = 2.0  → "2.0x"
    /// playbackSpeed = 1.75 → "1.8x" (rounded)
    /// ```
    ///
    /// **Usage in View:**
    /// ```swift
    /// Menu {
    ///     Button("0.5x") { ... }
    ///     Button("1.0x") { ... }
    ///     Button("2.0x") { ... }
    /// } label: {
    ///     Text(viewModel.playbackSpeedString)  // "1.0x"
    /// }
    /// ```
    var playbackSpeedString: String {
        return String(format: "%.1fx", playbackSpeed)
    }

    /// Convert time (TimeInterval) to "MM:SS" format string
    ///
    /// ## Conversion Algorithm
    /// ```
    /// 1. Convert TimeInterval(Double) → Int (truncate decimal)
    ///      ↓
    /// 2. minutes = totalSeconds / 60
    ///      ↓
    /// 3. seconds = totalSeconds % 60
    ///      ↓
    /// 4. String(format: "%02d:%02d", minutes, seconds)
    /// ```
    ///
    /// ## Format Explanation
    /// - %02d: 2-digit integer, pad with 0
    /// - Example: 5 → "05", 12 → "12"
    ///
    /// - Parameter time: Time to convert (in seconds)
    /// - Returns: "MM:SS" format string
    ///
    /// **Conversion Examples:**
    /// ```swift
    /// formatTime(0.0)    → "00:00"
    /// formatTime(5.7)    → "00:05" (truncate decimal)
    /// formatTime(65.0)   → "01:05" (1 minute 5 seconds)
    /// formatTime(125.0)  → "02:05" (2 minutes 5 seconds)
    /// formatTime(3665.0) → "61:05" (61 minutes 5 seconds)
    /// ```
    private func formatTime(_ time: TimeInterval) -> String {
        /// 1. Convert TimeInterval(Double) → Int
        ///
        /// ## Int(time)
        /// - Truncate decimal
        /// - 5.7 → 5, 125.9 → 125
        let totalSeconds = Int(time)

        /// 2. Calculate minutes
        ///
        /// ## totalSeconds / 60
        /// - Integer division (quotient only)
        /// - 65 / 60 = 1 (1 minute)
        /// - 125 / 60 = 2 (2 minutes)
        let minutes = totalSeconds / 60

        /// 3. Calculate seconds
        ///
        /// ## totalSeconds % 60
        /// - Remainder operation
        /// - 65 % 60 = 5 (5 seconds)
        /// - 125 % 60 = 5 (5 seconds)
        let seconds = totalSeconds % 60

        /// 4. Format
        ///
        /// ## String(format: "%02d:%02d", minutes, seconds)
        /// - %02d: 2-digit integer, pad with 0
        /// - minutes=1, seconds=5 → "01:05"
        /// - minutes=2, seconds=5 → "02:05"
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
