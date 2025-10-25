/// @file SyncController.swift
/// @brief Multi-channel synchronized playback controller
/// @author BlackboxPlayer Development Team
/// @details Controller that synchronizes and plays multiple video channels.
///          Synchronizes all channels based on master clock, performs drift correction and buffer management.

import Foundation
import Combine
import QuartzCore

/// @class SyncController
/// @brief Multi-channel synchronized playback controller class
/// @details Controller that synchronizes and plays multiple video channels.
///
/// **What is Synchronization?**
/// - Playing multiple videos (front, rear, left, right cameras) at the same time
/// - Example: Display front video at 5s and rear video at 5s simultaneously
/// - Like a conductor synchronizing all instruments (channels) in an orchestra
///
/// **What is Master Clock?**
/// - Common time reference that all channels follow
/// - Uses system time (CACurrentMediaTime)
/// - Each channel displays frames according to this clock
///
/// **What is Drift?**
/// - Phenomenon where time difference occurs between channels
/// - Example: Front camera at 5.0s but rear camera at 5.1s
/// - Causes: Decoding speed differences, buffering delays, etc.
/// - Solution: Detect and correct drift when it exceeds 50ms
///
/// **Main Features:**
/// 1. **Multi-channel Management**: Create and control multiple VideoChannel objects
/// 2. **Synchronized Playback**: Play all channels at the same time
/// 3. **Master Clock**: Time management based on CACurrentMediaTime()
/// 4. **Drift Correction**: Detect and correct time differences between channels
/// 5. **Buffer Monitoring**: Check buffer status of all channels
/// 6. **GPS/G-Sensor Sync**: Synchronize video with sensor data
/// 7. **Playback Control**: Play, pause, stop, seek
///
/// **Usage Example:**
/// ```swift
/// // 1. Create controller
/// let controller = SyncController()
///
/// // 2. Load video file
/// let videoFile = VideoFile(...)
/// try controller.loadVideoFile(videoFile)
///
/// // 3. Start playback
/// controller.play()
///
/// // 4. Get synchronized frames
/// let frames = controller.getSynchronizedFrames()
/// for (position, frame) in frames {
///     print("\(position.displayName): \(frame.timestamp)s")
/// }
///
/// // 5. Seek
/// controller.seekToTime(10.0)  // Jump to 10 seconds
///
/// // 6. Pause
/// controller.pause()
///
/// // 7. Stop
/// controller.stop()
/// ```
///
/// **Synchronization Mechanism:**
/// ```
/// Master Clock (System Time)
/// ↓
/// Calculate Current Playback Time
/// ↓
/// ┌─────┴─────┬─────────┬─────────┐
/// ↓          ↓         ↓         ↓
/// Front      Rear      Left      Right
/// 5.0s       4.98s     5.02s     5.01s
/// ↓          ↓         ↓         ↓
/// Drift Detection (0ms, 20ms, 20ms, 10ms)
/// ↓
/// Correction needed if ≥ 50ms
/// ```
///
/// **Thread Safety:**
/// - NSLock protects channels array
/// - Timer runs on main thread
/// - Each channel is internally thread-safe
class SyncController: ObservableObject {
    /*
     What is ObservableObject?
     - Protocol from Combine framework
     - Can have @Published properties
     - SwiftUI automatically updates UI
     - Sends objectWillChange signal when any @Published property changes
     */

    // MARK: - Published Properties

    /*
     @Published properties:
     - Automatically notify subscribers when value changes
     - SwiftUI View automatically re-renders
     - Works as a Combine Publisher
     */

    /// @var playbackState
    /// @brief Playback state
    ///
    /// PlaybackState types:
    /// - .stopped: Stopped (video not loaded or playback ended)
    /// - .playing: Playing
    /// - .paused: Paused
    ///
    /// State transitions:
    /// ```
    /// .stopped
    ///   ↓ loadVideoFile()
    /// .paused
    ///   ↓ play()
    /// .playing
    ///   ↓ pause()
    /// .paused
    ///   ↓ stop()
    /// .stopped
    /// ```
    ///
    /// private(set):
    /// - Read-only from outside
    /// - Can only be modified inside this class
    /// - controller.playbackState = .playing // Not allowed
    @Published private(set) var playbackState: PlaybackState = .stopped

    /// @var currentTime
    /// @brief Current playback time
    ///
    /// TimeInterval = Double (in seconds)
    ///
    /// Master time applied to all channels:
    /// - Range: 0.0 ~ duration
    /// - Calculated from master clock
    /// - All channels display frames according to this time
    ///
    /// Calculation method:
    /// ```
    /// Start time: playbackStartTime = 0.0
    /// Master clock start: masterClockStartTime = CACurrentMediaTime()
    ///
    /// During playback:
    /// elapsed time = CACurrentMediaTime() - masterClockStartTime
    /// current time = playbackStartTime + (elapsed time × playback speed)
    ///
    /// Example: 5 seconds elapsed at 2x speed
    /// currentTime = 0.0 + (5.0 × 2.0) = 10.0s
    /// ```
    @Published private(set) var currentTime: TimeInterval = 0.0

    /// **Playback Position**
    ///
    /// Range: 0.0 ~ 1.0 (ratio)
    /// - 0.0 = Start (0%)
    /// - 0.5 = Middle (50%)
    /// - 1.0 = End (100%)
    ///
    /// Calculation:
    /// playbackPosition = currentTime / duration
    ///
    /// Usage:
    /// - Display on UI progress bar
    /// - Used when dragging seek bar
    ///
    /// Example:
    /// - Playing at 5 minutes of 10-minute video
    /// - currentTime = 300.0, duration = 600.0
    /// - playbackPosition = 300.0 / 600.0 = 0.5
    @Published private(set) var playbackPosition: Double = 0.0

    /// **Playback Speed**
    ///
    /// Speed settings:
    /// - 0.5 = 0.5x speed (slow)
    /// - 1.0 = Normal speed
    /// - 2.0 = 2x speed (fast)
    /// - 4.0 = 4x speed (faster)
    ///
    /// Note:
    /// - var (variable): Can be changed from outside
    /// - controller.playbackSpeed = 2.0 // Allowed
    /// - Can be changed during playback
    /// - Immediately reflected in master clock calculation
    @Published var playbackSpeed: Double = 1.0

    /// **Is Buffering**
    ///
    /// What is buffering?
    /// - Process of pre-decoding frames
    /// - Temporarily pauses playback when buffer is empty
    ///
    /// When true:
    /// - One or more channel buffers below 20%
    /// - Can display "Loading" in UI
    ///
    /// When false:
    /// - All channel buffers are sufficient
    /// - Normal playback in progress
    @Published private(set) var isBuffering: Bool = false

    // MARK: - Properties

    /// **Video Channels Array**
    ///
    /// [VideoChannel]: Array of VideoChannel objects
    ///
    /// One channel per camera:
    /// - channels[0]: Front camera
    /// - channels[1]: Rear camera
    /// - channels[2]: Left camera
    /// - channels[3]: Right camera
    ///
    /// Thread safety:
    /// - Protected by channelsLock
    /// - Must lock/unlock when accessing
    ///
    /// Lifecycle:
    /// - loadVideoFile(): Create and initialize channels
    /// - stop(): Remove and cleanup channels
    private var channels: [VideoChannel] = []

    /// **GPS Service**
    ///
    /// What is GPS? (Global Positioning System)
    /// - Satellite-based position measurement system
    /// - Latitude, longitude, altitude
    /// - Dashcam records GPS data while driving
    ///
    /// Role:
    /// - Load GPS data from video metadata
    /// - Provide location info for current playback time
    /// - Display vehicle position on map UI
    ///
    /// private(set):
    /// - Read is public
    /// - Write is private
    /// - controller.gpsService.getCurrentLocation() // Allowed
    private(set) var gpsService: GPSService = GPSService()

    /// **G-Sensor Service**
    ///
    /// What is G-Sensor? (Gravity Sensor = Accelerometer)
    /// - Sensor that measures acceleration
    /// - X, Y, Z axis acceleration values (m/s²)
    /// - Detects rapid acceleration, braking, turning
    ///
    /// Role:
    /// - Load acceleration data from video metadata
    /// - Provide acceleration info for current playback time
    /// - Analyze impact strength at accident moment
    ///
    /// Examples:
    /// - Normal driving: X, Y, Z ≈ 0
    /// - Hard braking: Large negative Y-axis value
    /// - Sharp turn: Large X-axis value
    /// - Collision: Large values on all axes
    private(set) var gsensorService: GSensorService = GSensorService()

    /// **Channels Lock**
    ///
    /// Protects channels array with NSLock:
    ///
    /// Why needed?
    /// - Timer thread: Reads channels (getSynchronizedFrames)
    /// - loadVideoFile: Modifies channels (create, initialize)
    /// - stop: Modifies channels (remove)
    /// - Prevents crashes from concurrent access
    ///
    /// Usage pattern:
    /// ```swift
    /// channelsLock.lock()
    /// defer { channelsLock.unlock() }
    /// // Use channels array...
    /// ```
    ///
    /// Notes:
    /// - lock and unlock must be paired
    /// - Auto unlock with defer recommended
    /// - Don't call another lock while locked (deadlock)
    private let channelsLock = NSLock()

    /// **Total Duration**
    ///
    /// TimeInterval = Double (in seconds)
    ///
    /// Length of longest channel:
    /// - 4 channel lengths: 59.8s, 60.0s, 59.9s, 60.0s
    /// - duration = 60.0s (maximum value)
    ///
    /// Usage:
    /// - Maximum value for currentTime
    /// - Calculate playbackPosition (currentTime / duration)
    /// - Display total time in UI (e.g., "01:00")
    ///
    /// private(set):
    /// - Read allowed from outside
    /// - controller.duration // Allowed
    private(set) var duration: TimeInterval = 0.0

    /// **Master Clock Start Time**
    ///
    /// CFTimeInterval = Double (in seconds)
    ///
    /// What is CACurrentMediaTime()?
    /// - Core Animation's absolute time
    /// - Time elapsed since system boot
    /// - Accurate and monotonic
    /// - Very precise (nanosecond level)
    ///
    /// Role:
    /// - Record when play() is called: masterClockStartTime = CACurrentMediaTime()
    /// - Calculate current time: elapsedTime = CACurrentMediaTime() - masterClockStartTime
    ///
    /// Example:
    /// ```
    /// When play() is called:
    /// masterClockStartTime = 12345.678 (system time)
    /// playbackStartTime = 0.0 (video time)
    ///
    /// After 5 seconds:
    /// CACurrentMediaTime() = 12350.678
    /// elapsedTime = 12350.678 - 12345.678 = 5.0s
    /// currentTime = 0.0 + (5.0 × 1.0) = 5.0s
    /// ```
    private var masterClockStartTime: CFTimeInterval = 0.0

    /// **Playback Start Time**
    ///
    /// Video time when play() was called:
    ///
    /// Why needed?
    /// - Can start playback from middle
    /// - Example: Pause at 10s → Seek to 20s → Play
    /// - playbackStartTime = 20.0
    ///
    /// Time calculation:
    /// ```
    /// currentTime = playbackStartTime + (elapsed time × playback speed)
    /// ```
    ///
    /// Example 1: Play from start
    /// - playbackStartTime = 0.0
    /// - 5s elapsed → currentTime = 0.0 + 5.0 = 5.0s
    ///
    /// Example 2: Play from 10s
    /// - playbackStartTime = 10.0
    /// - 5s elapsed → currentTime = 10.0 + 5.0 = 15.0s
    private var playbackStartTime: TimeInterval = 0.0

    /// **Sync Timer**
    ///
    /// What is Timer?
    /// - Timer that executes repeatedly at fixed intervals
    /// - Runs in main thread's Run Loop
    ///
    /// Role:
    /// - Executes at 30fps (30 times per second)
    /// - Calls updateSync()
    /// - Updates currentTime
    /// - Detects drift
    /// - Checks buffer status
    ///
    /// Lifecycle:
    /// - play(): startSyncTimer() → Create and start timer
    /// - pause(): stopSyncTimer() → Stop timer
    /// - stop(): stopSyncTimer() → Remove timer
    ///
    /// Optional(?):
    /// - nil: No timer (stopped or paused)
    /// - Timer: Timer running (playing)
    private var syncTimer: Timer?

    /// **Drift Threshold**
    ///
    /// 50 milliseconds = 0.050 seconds
    ///
    /// Drift detection criteria:
    /// - Difference between channel's frame time and master time
    /// - Considered "drift occurred" if ≥ 50ms
    ///
    /// Why 50ms?
    /// - Human perception limit: about 50~100ms
    /// - ≤ 50ms: Hard to distinguish visually
    /// - ≥ 50ms: Appears out of sync
    ///
    /// Example:
    /// ```
    /// currentTime = 5.0s
    /// Front channel frame = 5.0s → drift 0ms (OK)
    /// Rear channel frame = 5.06s → drift 60ms (NG)
    /// ```
    ///
    /// let (constant):
    /// - Immutable
    /// - Compile-time optimization
    private let driftThreshold: TimeInterval = 0.050 // 50ms

    /// **Sync Check Interval**
    ///
    /// 100 milliseconds = 0.1 seconds
    ///
    /// Currently unused (using targetFrameRate instead):
    /// - Previously checked sync at this interval
    /// - Currently checks more frequently at 30fps (about 33ms interval)
    ///
    /// Reason kept:
    /// - Can be used for future performance optimization
    /// - Can change to 10fps (100ms) if 30fps is too demanding
    private let syncCheckInterval: TimeInterval = 0.1 // 100ms

    /// **Target Frame Rate**
    ///
    /// 30.0 FPS (Frames Per Second)
    ///
    /// What is frame rate?
    /// - How many times screen is updated per second
    /// - 30fps = 30 times per second = once every ~33ms
    ///
    /// Timer interval calculation:
    /// ```
    /// interval = 1.0 / 30.0 = 0.0333...s = 33.3ms
    /// ```
    ///
    /// Why 30fps?
    /// - Standard frame rate for general videos
    /// - Balance between smooth playback and performance
    /// - 60fps: Smoother but 2x CPU load
    /// - 24fps: Film standard but slightly less smooth
    ///
    /// Usage:
    /// - Determines syncTimer execution interval
    /// - updateSync() call frequency
    private let targetFrameRate: Double = 30.0

    // MARK: - Initialization

    /**
     Creates a sync controller.

     Empty initialization:
     - No initial setup
     - Channel array is empty
     - Need to load channels with loadVideoFile()

     Usage example:
     ```swift
     let controller = SyncController()
     try controller.loadVideoFile(videoFile)
     controller.play()
     ```
     */
    init() {
        // Empty initialization
        // All properties have default values at declaration
    }

    /**
     deinit (Deinitializer)

     Cleanup when memory is released:
     - Call stop()
     - Stop timer
     - Cleanup channels
     - Cleanup services

     Automatically called:
     - controller = nil
     - Automatically called when reference count reaches 0
     */
    deinit {
        stop()
    }

    // MARK: - Public Methods

    /**
     Loads a video file with multiple channels.

     Loading process:
     1. Stop current playback (stop)
     2. Create VideoChannel for each channel
     3. Initialize each channel (create VideoDecoder)
     4. Store in channel array
     5. Set total duration
     6. Load GPS, G-sensor data
     7. Set playback state to .paused

     Parameters:
     - videoFile: Video file to load
     - channels: Array of channel info
     - duration: Total playback time
     - metadata: GPS, G-sensor data
     - timestamp: Recording start time

     Usage example:
     ```swift
     let videoFile = VideoFile(
     name: "2025-01-12_14-30-00",
     channels: [
     ChannelInfo(position: .front, filePath: "front.mp4"),
     ChannelInfo(position: .rear, filePath: "rear.mp4")
     ],
     duration: 60.0,
     metadata: ...
     )

     do {
     try controller.loadVideoFile(videoFile)
     print("Load successful!")
     print("Channel count: \(controller.channelCount)")
     print("Duration: \(controller.duration)s")
     } catch {
     print("Load failed: \(error)")
     }
     ```

     Channel activation:
     - Only load channels where isEnabled is true
     - User can disable specific channels
     - Example: Disable left/right when only want front/rear

     Errors:
     - ChannelError.invalidState: No enabled channels
     - DecoderError: Channel initialization failed

     - Throws: ChannelError or DecoderError
     */
    func loadVideoFile(_ videoFile: VideoFile) throws {
        // 1. Stop current playback
        // - Cleanup previously loaded channels
        // - Stop timer
        // - Reset state
        stop()

        // 2. Create new channel array
        var newChannels: [VideoChannel] = []
        // Temporary array: Store in channels after all channels initialized successfully

        // 3. Create and initialize each channel
        // for-in with where: Iterate only elements matching condition
        for channelInfo in videoFile.channels where channelInfo.isEnabled {
            // Process only where channelInfo.isEnabled is true

            // 3-1. Create VideoChannel
            let channel = VideoChannel(channelInfo: channelInfo)
            // channelInfo: position, filePath, displayName

            // 3-2. Initialize channel
            // - Create VideoDecoder
            // - Open file with FFmpeg
            // - Find stream, initialize codec
            try channel.initialize()
            // On error, exit function and pass error to caller

            // 3-3. Add to temporary array
            newChannels.append(channel)
        }

        // 4. Error if no channels
        guard !newChannels.isEmpty else {
            // All channels disabled or
            // videoFile.channels is empty
            throw ChannelError.invalidState("No enabled channels found")
        }

        // 5. Store in channel array (thread-safe)
        channelsLock.lock()
        // Lock so other threads cannot access channels
        self.channels = newChannels
        // Replace channel array
        channelsLock.unlock()
        // Release lock

        // 6. Set total duration
        self.duration = videoFile.duration
        // Length of longest channel

        // 7. Load GPS data
        // - metadata: GPS coordinates array + timestamps
        // - startTime: Recording start time (Date)
        // - Match GPS data with playback time
        gpsService.loadGPSData(from: videoFile.metadata, startTime: videoFile.timestamp)

        // 8. Load G-sensor data
        // - metadata: Acceleration values array + timestamps
        // - startTime: Recording start time
        // - Match acceleration data with playback time
        gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)

        // 9. Reset playback state
        currentTime = 0.0
        playbackPosition = 0.0
        playbackState = .paused
        // Load complete, ready to play

        // Successfully loaded
        // Can call play()
    }

    /**
     Starts synchronized playback.

     Playback start process:
     1. Ignore if already playing
     2. Check if channels exist
     3. Start decoding all channels
     4. Record master clock start time
     5. Record playback start time
     6. Change state to .playing
     7. Start sync timer

     Master clock setup:
     ```
     masterClockStartTime = CACurrentMediaTime()
     playbackStartTime = currentTime

     Example: Start playback at currentTime = 10.0s
     - masterClockStartTime = 12345.678 (system time)
     - playbackStartTime = 10.0 (video time)

     After 3 seconds:
     - CACurrentMediaTime() = 12348.678
     - elapsedTime = 12348.678 - 12345.678 = 3.0
     - currentTime = 10.0 + 3.0 = 13.0s
     ```

     Usage examples:
     ```swift
     // Play from start
     try controller.loadVideoFile(videoFile)
     controller.play()

     // Play from middle
     controller.seekToTime(30.0)  // Jump to 30s
     controller.play()            // Start playback from 30s

     // Resume after pause
     controller.pause()
     // ... some time later ...
     controller.play()  // Resume from paused position
     ```

     Synchronization mechanism:
     - All channels decode independently
     - syncTimer periodically updates currentTime
     - Each channel calls getFrame(at: currentTime)
     - Displays frame closest to master time

     Notes:
     - Must call loadVideoFile() first
     - Won't play if no channels
     - Ignored if already playing
     */
    func play() {
        // 1. Ignore if already playing
        guard playbackState != .playing else {
            return
        }

        // 2. Check channels (thread-safe)
        channelsLock.lock()
        // Lock

        let isEmpty = channels.isEmpty
        // Check if channels exist

        let channelsCopy = channels
        // Copy array: for use after lock release
        // Reference copy (shallow): Points to same VideoChannel objects
        // Safe to use after lock release

        channelsLock.unlock()
        // Release lock (as soon as possible)

        // 3. Exit with warning if no channels
        guard !isEmpty else {
            warningLog("[SyncController] Cannot play: no channels loaded")
            // Log output: Channels not loaded
            return
        }

        // 4. Log playback start
        infoLog("[SyncController] Starting playback with \(channelsCopy.count) channels")
        // Example: "Starting playback with 4 channels"

        // 5. Start decoding all channels
        for channel in channelsCopy {
            infoLog("[SyncController] Starting decoding for channel: \(channel.channelInfo.position.displayName)")
            // Example: "Starting decoding for channel: Front Camera"

            channel.startDecoding()
            // Start frame decoding in background
            // Each channel decodes independently
            // Frames accumulate in buffer
        }

        // 6. Set master clock
        masterClockStartTime = CACurrentMediaTime()
        // Record system time
        // Example: 12345.678s (time elapsed since system boot)

        playbackStartTime = currentTime
        // Record current video time
        // From start: 0.0, from middle: seeked position

        // 7. Change state
        playbackState = .playing
        // @Published so UI updates automatically
        // In SwiftUI: Play button → Pause button

        // 8. Start sync timer
        startSyncTimer()
        // Repeatedly call updateSync() at 30fps
        // Update currentTime
        // Detect drift
        // Check buffer status

        // Playback started
        // Timer continues running in background
    }

    /**
     Pauses synchronized playback.

     Pause process:
     1. Ignore if not playing
     2. Change state to .paused
     3. Stop sync timer

     Notes:
     - Channel decoding continues (not stopped)
     - Buffer continues filling
     - Only timer stops so currentTime doesn't increase
     - Screen freezes on last frame

     Resume:
     - Call play() again
     - Playback resumes from paused position

     Usage example:
     ```swift
     controller.play()   // Start playback
     // ... playing ...
     controller.pause()  // Pause
     // ... stopped ...
     controller.play()   // Resume (from paused position)
     ```
     */
    func pause() {
        // 1. Ignore if not playing
        guard playbackState == .playing else {
            return
        }

        // 2. Change state
        playbackState = .paused
        // @Published so UI updates automatically

        // 3. Stop timer
        stopSyncTimer()
        // Invalidate and remove Timer
        // Stop calling updateSync()
        // currentTime stops increasing

        // Pause complete
        // Channel decoding continues (buffering continues)
        // Screen frozen on current frame
    }

    /**
     Toggles between play and pause.

     What is Toggle?
     - Alternates between two states
     - Like turning a switch on and off

     Behavior:
     - .playing → pause() → .paused
     - .paused → play() → .playing
     - .stopped → play() → .playing

     Usage example:
     ```swift
     // Press spacebar key
     controller.togglePlayPause()
     ```

     UI button:
     - Single play/pause button for both functions
     - Calls togglePlayPause() on click
     */
    func togglePlayPause() {
        if playbackState == .playing {
            // If playing → pause
            pause()
        } else {
            // If paused or stopped → play
            play()
        }
    }

    /**
     Stops playback and resets all state.

     Stop process:
     1. Stop sync timer
     2. Stop and remove all channels
     3. Clear GPS, G-sensor data
     4. Reset playback state

     stop() vs pause():
     - pause: Temporarily paused, can resume
     - stop: Complete stop, restart from beginning

     Memory cleanup:
     - Release all channel decoders
     - Clear buffers
     - Clear service data

     When to use:
     - Video ended
     - Load different video
     - Prepare app exit

     Usage example:
     ```swift
     controller.play()
     // ... playing ...
     controller.stop()  // Stop

     // Check state
     print(controller.playbackState)     // .stopped
     print(controller.currentTime)       // 0.0
     print(controller.channelCount)      // 0
     ```
     */
    func stop() {
        // 1. Stop timer
        stopSyncTimer()
        // Invalidate and remove Timer
        // Stop calling updateSync()

        // 2. Copy and remove channel array (thread-safe)
        channelsLock.lock()

        let channelsCopy = channels
        // Copy array: for use after lock release

        channels.removeAll()
        // Clear array
        // Decrease reference count
        // Start memory release if no other references

        channelsLock.unlock()

        // 3. Stop each channel (outside lock)
        for channel in channelsCopy {
            channel.stop()
            // - Stop decoding
            // - Clear buffer
            // - Release decoder
            // - Cleanup memory
        }

        // 4. Clear GPS, G-sensor data
        gpsService.clear()
        // Clear GPS data array

        gsensorService.clear()
        // Clear acceleration data array

        // 5. Reset playback state
        playbackState = .stopped
        currentTime = 0.0
        playbackPosition = 0.0
        duration = 0.0
        // @Published properties: UI updates automatically

        // Stop complete
        // Memory usage minimized
        // Can call loadVideoFile() again
    }

    /**
     Seeks all channels to a specific time.

     What is Seek?
     - Jump to specific position in video
     - Dragging the progress bar

     Seek process:
     1. Clamp time to valid range (0 ~ duration)
     2. Pause if playing
     3. Seek all channels to new position
     4. Update currentTime, playbackPosition
     5. Update GPS, G-sensor data to new position
     6. Resume if was playing

     Time clamping:
     ```
     Input time: -5.0  → Clamped: 0.0 (no negative)
     Input time: 30.0  → Clamped: 30.0 (normal)
     Input time: 100.0 → Clamped: 60.0 (can't exceed duration)
     ```

     Parameters:
     - time: Time to seek to (in seconds)

     Usage examples:
     ```swift
     // Seek to 10 seconds
     controller.seekToTime(10.0)

     // Seek to start
     controller.seekToTime(0.0)

     // Seek to end
     controller.seekToTime(controller.duration)

     // Seek to middle
     controller.seekToTime(controller.duration / 2)
     ```

     UI integration:
     ```swift
     // Slider (progress bar)
     Slider(value: $seekPosition, in: 0...controller.duration)
     .onChange(of: seekPosition) { newValue in
     controller.seekToTime(newValue)
     }
     ```

     Channel seeking:
     - Each channel seeks independently
     - Calls VideoDecoder's av_seek_frame()
     - Jumps to keyframe (I-frame)
     - Clears buffer and starts decoding from new position

     Notes:
     - Seeking only possible to keyframes
     - May not be exact desired time
     - ±1s error possible
     */
    func seekToTime(_ time: TimeInterval) {
        // 1. Clamp time to valid range
        let clampedTime = max(0.0, min(duration, time))
        // max(0.0, time): >= 0
        // min(duration, time): <= duration
        // Result: 0 ~ duration range

        // 2. Save playback state and pause
        let wasPlaying = playbackState == .playing
        // Remember if was playing

        if wasPlaying {
            pause()
            // Pause during seek
            // Stop timer
        }

        // 3. Copy channel array (thread-safe)
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        // 4. Seek all channels
        for channel in channelsCopy {
            do {
                try channel.seek(to: clampedTime)
                // Call VideoDecoder.seek()
                // FFmpeg av_seek_frame()
                // Clear buffer
                // Prepare to decode from new position
            } catch {
                // Seek failed (file corruption, etc.)
                print("Failed to seek channel \(channel.channelInfo.position.displayName): \(error)")
                // Only log error, continue
            }
        }

        // 5. Update current time
        currentTime = clampedTime
        playbackPosition = duration > 0 ? clampedTime / duration : 0.0
        // Example: 30s / 60s = 0.5 (50%)

        // 6. Update GPS, G-sensor data
        _ = gpsService.getCurrentLocation(at: clampedTime)
        // GPS position at new time
        // Update vehicle position on map

        _ = gsensorService.getCurrentAcceleration(at: clampedTime)
        // Acceleration value at new time
        // Update G-sensor graph

        // 7. Resume playback (if needed)
        if wasPlaying {
            // If was playing
            play()
            // Start playback from new position
            // Reset master clock
        }

        // Seek complete
        // Display frame at new time on screen
    }

    /**
     Seeks by a relative amount of time.

     Relative Seek:
     - Move forward/backward from current position
     - seekToTime(currentTime + seconds)

     Parameters:
     - seconds: Seconds to move
     - Positive: Forward (fast forward)
     - Negative: Backward (rewind)

     Usage examples:
     ```swift
     // 10 seconds forward
     controller.seekBySeconds(10.0)

     // 5 seconds backward
     controller.seekBySeconds(-5.0)

     // Keyboard shortcuts
     // Arrow key →: seekBySeconds(10.0)
     // Arrow key ←: seekBySeconds(-10.0)
     ```

     UI buttons:
     ```
     [<<] [-10s] [Play/Pause] [+10s] [>>]
     ```
     */
    func seekBySeconds(_ seconds: Double) {
        seekToTime(currentTime + seconds)
        // Current time + seconds = new time
        // seekToTime() automatically clamps range
    }

    /**
     Gets all channel frames at current time.

     Synchronized frames:
     - Frames closest to currentTime
     - One per channel
     - Returned as dictionary (camera position → frame)

     Return value:
     - [CameraPosition: VideoFrame]
     - Keys: .front, .rear, .left, .right, .interior
     - Values: VideoFrame (pixel data, timestamp, etc.)

     Usage examples:
     ```swift
     let frames = controller.getSynchronizedFrames()

     // Front camera frame
     if let frontFrame = frames[.front] {
     print("Front: \(frontFrame.timestamp)s")
     // Draw on screen with frontFrame.pixelBuffer
     }

     // Iterate all channels
     for (position, frame) in frames {
     print("\(position.displayName): \(frame.timestamp)s")
     }
     ```

     Rendering pipeline:
     ```
     getSynchronizedFrames()
     ↓
     [.front: Frame(5.0s), .rear: Frame(5.02s)]
     ↓
     MultiChannelRenderer
     ↓
     Metal rendering
     ↓
     Display on screen
     ```

     Returns empty dictionary when:
     - No channels
     - Buffer empty (not decoded yet)

     - Returns: Dictionary of frames by camera position
     */
    func getSynchronizedFrames() -> [CameraPosition: VideoFrame] {
        // 1. Copy channel array (thread-safe)
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        // 2. Create result dictionary
        var frames: [CameraPosition: VideoFrame] = [:]
        // Start with empty dictionary

        // 3. Get frame from each channel (apply time offset)
        for channel in channelsCopy {
            // Apply per-channel time offset
            // Example: currentTime = 5.0, timeOffset = 0.05
            //     → adjustedTime = 5.05
            //     → Get frame at 5.05s from this channel
            let adjustedTime = currentTime + channel.channelInfo.timeOffset

            // getFrame(at:): Frame closest to adjustedTime
            if let frame = channel.getFrame(at: adjustedTime) {
                // If frame found
                frames[channel.channelInfo.position] = frame
                // Add to dictionary
                // Example: frames[.front] = frontFrame
            }
            // If no frame (buffer empty), ignore
        }

        // 4. Return result
        return frames
        // Example: [.front: Frame1, .rear: Frame2]
        // All frames are synchronized with time offset applied

        // Renderer draws these frames on screen
    }

    /**
     Gets buffer status of all channels.

     Buffer status info:
     - current: Number of frames currently in buffer
     - max: Maximum buffer size (30)
     - fillPercentage: Fill ratio (0.0 ~ 1.0)

     Return value:
     - [CameraPosition: (current, max, fillPercentage)]
     - Buffer status tuple by camera position

     Usage examples:
     ```swift
     let status = controller.getBufferStatus()

     // Front camera buffer status
     if let frontStatus = status[.front] {
     print("Front buffer: \(frontStatus.current)/\(frontStatus.max)")
     print("Fill rate: \(frontStatus.fillPercentage * 100)%")

     if frontStatus.fillPercentage < 0.2 {
     print("Buffer low!")
     }
     }

     // Check all channels
     for (position, bufferStatus) in status {
     print("\(position.displayName): \(Int(bufferStatus.fillPercentage * 100))%")
     }
     ```

     UI display:
     ```
     Front: ████████░░ 80%
     Rear:  ██████████ 100%
     Left:  ████░░░░░░ 40%
     Right: ██████░░░░ 60%
     ```

     Low buffer detection:
     - < 20%: Show loading indicator
     - 100%: Normal playback
     - 0%: Buffer empty (initial state)

     - Returns: Dictionary of buffer status by camera position
     */
    func getBufferStatus() -> [CameraPosition: (current: Int, max: Int, fillPercentage: Double)] {
        // 1. Copy channel array (thread-safe)
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        // 2. Create result dictionary
        var status: [CameraPosition: (current: Int, max: Int, fillPercentage: Double)] = [:]

        // 3. Get buffer status from each channel
        for channel in channelsCopy {
            status[channel.channelInfo.position] = channel.getBufferStatus()
            // Call VideoChannel.getBufferStatus()
            // Returns tuple: (current, max, fillPercentage)
        }

        // 4. Return result
        return status
    }

    /// **Channel Count**
    ///
    /// Computed property:
    /// - Doesn't store value
    /// - Calculated on each call
    ///
    /// Thread-safe:
    /// - Uses lock/unlock
    /// - Auto unlock with defer
    ///
    /// Usage example:
    /// ```swift
    /// print("Channel count: \(controller.channelCount)")
    /// // 4
    /// ```
    var channelCount: Int {
        channelsLock.lock()
        defer { channelsLock.unlock() }
        return channels.count
    }

    /// **Check if all channels are ready**
    ///
    /// Ready states:
    /// - .ready: Initialization complete, can start decoding
    /// - .decoding: Currently decoding
    ///
    /// Not ready states:
    /// - .idle: Not initialized
    /// - .error: Error occurred
    /// - .completed: Completed (end of file)
    ///
    /// allSatisfy:
    /// - Check if all elements satisfy condition
    /// - true: All channels are .ready or .decoding
    /// - false: At least one in different state
    ///
    /// Usage example:
    /// ```swift
    /// if controller.allChannelsReady {
    ///     print("Ready to play!")
    ///     controller.play()
    /// } else {
    ///     print("Preparing...")
    /// }
    /// ```
    var allChannelsReady: Bool {
        channelsLock.lock()
        defer { channelsLock.unlock() }

        // Must have at least one channel and
        // All channels must be in .ready or .decoding state
        return !channels.isEmpty && channels.allSatisfy { channel in
            channel.state == .ready || channel.state == .decoding
        }
    }

    // MARK: - Private Methods

    /**
     Starts the sync timer.

     Timer creation:
     - 30fps = 30 times per second = about every 33.3ms
     - Repeatedly calls updateSync()
     - Runs in main thread's Run Loop

     Timer.scheduledTimer:
     - withTimeInterval: Execution interval
     - repeats: true = repeated execution
     - [weak self]: Prevents retain cycle

     Operation sequence:
     1. Stop existing timer (if any)
     2. Calculate interval (1.0 / 30.0)
     3. Create and start timer
     4. Automatically added to Run Loop
     */
    private func startSyncTimer() {
        // 1. Stop existing timer
        stopSyncTimer()
        // Stop if timer already running
        // Prevent duplicates

        // 2. Calculate interval
        let interval = 1.0 / targetFrameRate
        // 1.0 / 30.0 = 0.0333...s = 33.3ms

        // 3. Create timer
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // [weak self]: Prevents retain cycle
            // Timer weakly references self
            // Timer auto-cleaned when self is released

            self?.updateSync()
            // Call updateSync()
            // Update currentTime
            // Detect drift
            // Check buffer status
        }

        // Timer automatically added to main Run Loop
        // Continues running in background
    }

    /**
     Stops the sync timer.

     Timer cleanup:
     - invalidate(): Invalidate timer
     - nil: Release memory

     Called from:
     - pause()
     - stop()
     - startSyncTimer() (before creating new timer)

     Notes:
     - Can't reuse after invalidate()
     - Must create new Timer to restart
     */
    private func stopSyncTimer() {
        // 1. Invalidate timer
        syncTimer?.invalidate()
        // Stop Timer
        // Remove from Run Loop
        // No more updateSync() calls

        // 2. Set to nil
        syncTimer = nil
        // Set Optional to nil
        // Release memory
    }

    /**
     Updates synchronization state.

     Called by timer at 30fps:
     - Executes about every 33ms
     - Only operates when playing

     Update process:
     1. Calculate current time from master clock
     2. Update currentTime, playbackPosition
     3. Update GPS, G-sensor data
     4. Check if reached end of file
     5. Detect and correct drift
     6. Check buffer status

     Master clock calculation:
     ```
     elapsedTime = CACurrentMediaTime() - masterClockStartTime
     videoTime = playbackStartTime + (elapsedTime × playbackSpeed)

     Example: 5 seconds elapsed at 2x speed
     - masterClockStartTime = 12345.0
     - playbackStartTime = 0.0
     - CACurrentMediaTime() = 12350.0
     - elapsedTime = 5.0
     - videoTime = 0.0 + (5.0 × 2.0) = 10.0s
     ```

     Auto stop:
     - Calls stop() if currentTime >= duration
     - Reached end of file
     */
    private func updateSync() {
        // 1. Check if playing
        guard playbackState == .playing else {
            return  // Ignore if not playing
        }

        // 2. Calculate current time from master clock
        let elapsedTime = CACurrentMediaTime() - masterClockStartTime
        // Time elapsed from playback start to now (seconds)

        let videoTime = playbackStartTime + (elapsedTime * playbackSpeed)
        // Playback start time + (elapsed time × playback speed)
        // Increases 2x faster if playbackSpeed is 2.0

        // 3. Update current time
        currentTime = videoTime
        playbackPosition = duration > 0 ? currentTime / duration : 0.0
        // @Published properties: UI updates automatically

        // 4. Update GPS, G-sensor data
        _ = gpsService.getCurrentLocation(at: currentTime)
        // GPS position at current time
        // Update vehicle position on map

        _ = gsensorService.getCurrentAcceleration(at: currentTime)
        // Acceleration value at current time
        // Update G-sensor graph

        // 5. Check if reached end of file
        if currentTime >= duration {
            // Reached end of video
            stop()
            // Stop playback
            // Stop timer
            // Cleanup channels

            currentTime = duration
            playbackPosition = 1.0
            // Set to exact end position
            return
        }

        // 6. Detect and correct drift
        checkAndCorrectDrift()
        // Check time differences between channels
        // Log if >= 50ms

        // 7. Check buffer status
        checkBufferStatus()
        // Set isBuffering = true if buffer < 20%
    }

    /**
     Detects and corrects drift between channels.

     What is Drift?
     - Difference between channel's frame time and master time
     - Caused by decoding speed differences
     - Detected if >= 50ms, auto-corrected if >= 100ms

     Detection and correction process:
     1. Get current frame from all channels
     2. Compare each frame's timestamp with target time
     3. Log if difference >= driftThreshold (50ms)
     4. Auto re-seek if difference >= 100ms (severe drift)

     Correction methods:
     - 50ms ~ 100ms: Only log, expect natural catch-up
     - >= 100ms: Auto re-seek for immediate correction

     Example:
     ```
     currentTime = 5.0s
     Front frame = 5.0s → drift 0ms (OK)
     Rear frame = 5.06s → drift 60ms (log)
     Left frame = 5.15s → drift 150ms (re-seek!)
     ```
     */
    private func checkAndCorrectDrift() {
        // 1. Copy channel array (thread-safe)
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        // 2. Calculate and correct drift for each channel
        for channel in channelsCopy {
            // 2-1. Calculate target time per channel (apply time offset)
            let targetTime = currentTime + channel.channelInfo.timeOffset

            // 2-2. Get current frame
            guard let frame = channel.getFrame(at: targetTime) else {
                // Skip if no frame (buffer empty)
                continue
            }

            // 2-3. Calculate drift
            let drift = abs(frame.timestamp - targetTime)
            // abs: Absolute value
            // Difference between frame time and target time

            // 2-4. Handle based on drift level
            if drift > 0.100 {
                // >= 100ms: Severe drift → Auto re-seek
                warningLog("[SyncController] Channel \(channel.channelInfo.position.displayName) severe drift detected: \(Int(drift * 1000))ms - auto-correcting")

                // Re-seek in background (prevent main thread blocking)
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try channel.seek(to: targetTime)
                        infoLog("[SyncController] Channel \(channel.channelInfo.position.displayName) drift corrected by seeking to \(targetTime)s")
                    } catch {
                        errorLog("[SyncController] Failed to correct drift for channel \(channel.channelInfo.position.displayName): \(error)")
                    }
                }

            } else if drift > driftThreshold {
                // 50ms ~ 100ms: Minor drift → Only log
                debugLog("[SyncController] Channel \(channel.channelInfo.position.displayName) minor drift: \(Int(drift * 1000))ms")
                // Expect natural catch-up
                // Drift decreases as buffering normalizes
            }
            // < 50ms: Normal range, do nothing
        }
    }

    /**
     Checks buffer status of all channels.

     Low buffer detection:
     - One or more channel buffers < 20%
     - Set isBuffering = true
     - Can display "Loading" in UI

     Normal buffer:
     - All channel buffers >= 20%
     - Set isBuffering = false
     - Normal playback in progress

     Causes of low buffer:
     - Decoding speed can't keep up with playback speed
     - File read delay (HDD, network drive)
     - CPU overload

     Solutions:
     - Temporarily pause playback (until buffer fills)
     - Lower playback speed
     - Increase buffer size
     */
    private func checkBufferStatus() {
        // 1. Get buffer status of all channels
        let bufferStatus = getBufferStatus()
        // [CameraPosition: (current, max, fillPercentage)]

        // 2. Check if any channel has low buffer
        let isAnyBufferLow = bufferStatus.values.contains { status in
            // values: Dictionary values (tuples)
            // contains: Check if any element matches condition

            status.fillPercentage < 0.2
            // true if < 20%
        }

        // 3. Update buffering state
        if isAnyBufferLow && !isBuffering {
            // Buffer low but isBuffering still false
            print("Warning: Low buffer detected in some channels")
            isBuffering = true
            // @Published: Display "Loading" in UI
        } else if !isAnyBufferLow && isBuffering {
            // Buffer sufficient but isBuffering is true
            isBuffering = false
            // @Published: Hide "Loading"
        }
    }
}

// MARK: - Computed Properties

/**
 Time formatting related computed properties

 What are computed properties?
 - Calculate and return value without storing
 - Recalculated on each call
 - Can be used directly in UI

 Time format:
 - MM:SS format (minutes:seconds)
 - Range: 00:00 ~ 99:59
 - Always 2 digits (pad with 0)
 */
extension SyncController {
    /// **Current Time String**
    ///
    /// Converts currentTime to "MM:SS" format
    ///
    /// Examples:
    /// - currentTime = 65.0 → "01:05"
    /// - currentTime = 5.0 → "00:05"
    /// - currentTime = 125.0 → "02:05"
    ///
    /// Usage example:
    /// ```swift
    /// Text(controller.currentTimeString)  // "01:30"
    /// ```
    var currentTimeString: String {
        return formatTime(currentTime)
    }

    /// **Duration String**
    ///
    /// Converts duration to "MM:SS" format
    ///
    /// Examples:
    /// - duration = 60.0 → "01:00"
    /// - duration = 600.0 → "10:00"
    ///
    /// Usage example:
    /// ```swift
    /// Text(controller.durationString)  // "05:30"
    /// ```
    var durationString: String {
        return formatTime(duration)
    }

    /// **Remaining Time String**
    ///
    /// Remaining time = duration - currentTime
    /// Prepend with "-" (convention)
    ///
    /// Examples:
    /// - currentTime = 30, duration = 60 → "-00:30"
    /// - currentTime = 50, duration = 60 → "-00:10"
    ///
    /// Usage example:
    /// ```swift
    /// Text(controller.remainingTimeString)  // "-02:15"
    /// ```
    var remainingTimeString: String {
        let remaining = max(0, duration - currentTime)
        // Prevent negative (at end of file)
        return "-\(formatTime(remaining))"
        // Return with "-" prepended
    }

    /// **Playback Speed String**
    ///
    /// Converts playbackSpeed to "X.Xx" format
    /// 1 decimal place
    ///
    /// Examples:
    /// - playbackSpeed = 1.0 → "1.0x"
    /// - playbackSpeed = 2.0 → "2.0x"
    /// - playbackSpeed = 0.5 → "0.5x"
    ///
    /// Usage example:
    /// ```swift
    /// Text(controller.playbackSpeedString)  // "2.0x"
    /// ```
    var playbackSpeedString: String {
        return String(format: "%.1fx", playbackSpeed)
        // %.1f: 1 decimal place
        // x: Speed indicator
    }

    /**
     Converts time to "MM:SS" format.

     Conversion process:
     1. Convert TimeInterval(Double) to Int
     2. Minutes = total seconds / 60
     3. Seconds = total seconds % 60 (remainder)
     4. Format as "%02d:%02d"

     Format description:
     - %02d: 2-digit integer, pad with 0
     - Example: 5 → "05", 12 → "12"

     Examples:
     - 65s → 1m 5s → "01:05"
     - 125s → 2m 5s → "02:05"
     - 5s → 0m 5s → "00:05"

     Parameters:
     - time: Time to convert (seconds)

     Returns:
     - "MM:SS" format string

     - Returns: Formatted time string
     */
    private func formatTime(_ time: TimeInterval) -> String {
        // 1. Convert to integer
        let totalSeconds = Int(time)
        // Double → Int
        // Truncate decimal

        // 2. Calculate minutes
        let minutes = totalSeconds / 60
        // Division (quotient)
        // 65 / 60 = 1

        // 3. Calculate seconds
        let seconds = totalSeconds % 60
        // Modulo operation
        // 65 % 60 = 5

        // 4. Format
        return String(format: "%02d:%02d", minutes, seconds)
        // %02d: 2 digits, pad with 0
        // Example: (1, 5) → "01:05"
    }
}
