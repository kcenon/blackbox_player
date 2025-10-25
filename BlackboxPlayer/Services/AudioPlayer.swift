/// @file AudioPlayer.swift
/// @brief AVAudioEngine-based audio playback service
/// @author BlackboxPlayer Development Team
/// @details
/// This service plays AudioFrames decoded by FFmpeg through the actual speaker.
/// It uses Apple's AVAudioEngine to play PCM audio data in real-time.
///
/// ## What is AVAudioEngine?
/// Apple's framework for low-level audio processing on macOS/iOS.
/// You can build complex audio pipelines by connecting multiple audio "nodes".
///
/// ## AVAudioEngine's Node-Based Architecture:
/// ```
/// ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
/// │ PlayerNode   │ ───▶ │  MixerNode   │ ───▶ │ Output (🔊) │
/// │ (Playback)   │      │  (Mix/Volume) │      │ (Speaker)    │
/// └──────────────┘      └──────────────┘      └──────────────┘
///      ↑
/// PCM buffer input
/// ```
///
/// ## Data Flow:
/// 1. VideoDecoder creates AudioFrame (FFmpeg decoding)
/// 2. Call AudioPlayer.enqueue(frame)
/// 3. frame.toAudioBuffer() → Convert to AVAudioPCMBuffer
/// 4. playerNode.scheduleBuffer() → Add to playback queue
/// 5. AVAudioEngine automatically plays buffers
/// 6. Output to speaker 🔊
///
/// ## Buffering Strategy:
/// This player maintains up to 30 audio frames in the queue.
/// - Each frame ≈ 21ms (1024 samples / 48kHz)
/// - 30 frames = approximately 630ms (0.63 seconds) buffer
/// - Sufficient buffer to absorb network latency or decoding delays
///
/// ## Thread Safety:
/// Since multiple threads can access concurrently:
/// - Use NSLock for frameQueue access
/// - Use [weak self] in callbacks (to prevent memory retain cycles)

import Foundation
import AVFoundation

// MARK: - AudioPlayer Class

/// @class AudioPlayer
/// @brief AVAudioEngine-based audio player
///
/// @details
/// Plays AudioFrames decoded by FFmpeg in real-time through AVAudioEngine.
/// Core component responsible for the audio track during video playback.
///
/// ## Architecture
/// ```
/// AudioPlayer (this class)
///     │
///     ├─ AVAudioEngine: Manages entire audio system
///     │     │
///     │     ├─ AVAudioPlayerNode: PCM buffer playback
///     │     │     └─ scheduleBuffer() → Add buffer to queue
///     │     │
///     │     ├─ AVAudioMixerNode: Volume control and mixing
///     │     │     └─ outputVolume = 0.0 ~ 1.0
///     │     │
///     │     └─ Output Device: System speaker
///     │
///     └─ frameQueue: Frames waiting for playback
///           └─ NSLock: Thread safety guarantee
/// ```
///
/// ## Audio Playback Pipeline
/// ```
/// VideoDecoder (decoding thread)
///     │
///     │ enqueue(AudioFrame)
///     ↓
/// [frameQueue] ← Protected by NSLock
///     │
///     │ scheduleBuffer()
///     ↓
/// AVAudioPlayerNode
///     │
///     │ Automatic playback
///     ↓
/// AVAudioMixerNode (apply volume)
///     │
///     ↓
/// 🔊 Speaker
/// ```
///
/// ## Buffering Mechanism
/// ```
/// maxQueueSize = 30 frames
///
/// [Frame1][Frame2][Frame3]...[Frame30]
///   21ms   21ms    21ms  ...   21ms
///
/// Total buffer: 30 × 21ms = 630ms (0.63 seconds)
///
/// If buffer insufficient: Audio stuttering (underrun)
/// If buffer excessive: Increased latency, memory waste
/// 30 frames = optimal balance
/// ```
///
/// ## Thread Safety
/// ```
/// Decoding thread ──┐
///                   ├─▶ [NSLock] ──▶ frameQueue ──┐
/// Callback thread ──┘                              ├─▶ Safe access
/// Main thread ─────────────────────────────────────┘
/// ```
class AudioPlayer {
    // MARK: - Properties

    /// @var audioEngine
    /// @brief AVAudioEngine instance
    ///
    /// @details
    /// Core class of Apple's low-level audio framework.
    /// You can build complex audio pipelines by connecting multiple audio nodes
    /// (PlayerNode, MixerNode, EffectNode, etc.).
    ///
    /// Key roles:
    /// - Audio graph management: Maintain node connection relationships
    /// - Audio stream control: start(), stop()
    /// - Hardware abstraction: Support various audio devices
    ///
    /// Lifecycle:
    /// ```
    /// 1. Initialize: AVAudioEngine()
    /// 2. Connect nodes: connect(playerNode, to: mixer, format: format)
    /// 3. Start: try engine.start()
    /// 4. Run: Automatically process audio
    /// 5. Stop: engine.stop()
    /// ```
    private let audioEngine: AVAudioEngine

    /// @var playerNode
    /// @brief AVAudioPlayerNode instance
    ///
    /// @details
    /// Node that plays PCM audio buffers.
    /// When multiple buffers are added to the queue, they play automatically in sequence.
    ///
    /// Key features:
    /// - `scheduleBuffer()`: Add buffer to playback queue
    /// - `play()`: Start playback
    /// - `pause()`: Pause (queue retained)
    /// - `stop()`: Stop (clear queue)
    ///
    /// Buffer scheduling method:
    /// ```
    /// playerNode.scheduleBuffer(buffer1)  ← First buffer
    /// playerNode.scheduleBuffer(buffer2)  ← Second buffer
    /// playerNode.scheduleBuffer(buffer3)  ← Third buffer
    ///
    /// Playback order: buffer1 → buffer2 → buffer3 → (end)
    ///
    /// Completion handler called when each buffer finishes:
    /// scheduleBuffer(buffer1) { print("buffer1 complete!") }
    /// ```
    ///
    /// How it works:
    /// ```
    /// [Internal Queue]
    /// ┌───────┬───────┬───────┬───────┐
    /// │ Buf1  │ Buf2  │ Buf3  │ Buf4  │
    /// └───────┴───────┴───────┴───────┘
    ///    ↑ Currently playing
    ///
    /// Playback complete → Automatically move to next buffer
    /// Buf1 complete → Buf2 playback starts
    /// ```
    ///
    /// Preventing Underrun (buffer starvation):
    /// ```
    /// Queue empty → Audio stuttering!
    ///
    /// Solution: Always maintain sufficient buffers
    /// Recommended: Minimum 3~5 buffers (approximately 100~200ms)
    /// Current implementation: Maximum 30 buffers (approximately 630ms)
    /// ```
    private let playerNode: AVAudioPlayerNode

    /// @var mixer
    /// @brief AVAudioMixerNode instance
    ///
    /// @details
    /// Node that mixes multiple audio streams and controls volume.
    /// AVAudioEngine provides mainMixerNode by default.
    ///
    /// Key features:
    /// - Volume control: `outputVolume = 0.0 ~ 1.0`
    /// - Multiple input mixing: Combines multiple PlayerNodes into one
    /// - Final output: Send to speaker or other nodes
    ///
    /// Volume scale:
    /// ```
    /// outputVolume = 0.0  → Silence (mute)
    /// outputVolume = 0.5  → 50% volume
    /// outputVolume = 1.0  → 100% volume (original)
    /// outputVolume > 1.0  → Amplification (clipping possible)
    /// ```
    ///
    /// Mixing example:
    /// ```
    /// PlayerNode1 (music)  ──┐
    ///                        ├─▶ MixerNode ──▶ 🔊
    /// PlayerNode2 (effects) ──┘     ↑
    ///                           outputVolume
    /// ```
    private let mixer: AVAudioMixerNode

    /// @var volume
    /// @brief Current volume level (0.0 ~ 1.0)
    ///
    /// @details
    /// Readable from outside, but writing is only possible through `setVolume()` method.
    /// This ensures the validity of volume values.
    ///
    /// Range constraints:
    /// ```
    /// Input: -5.0 → Actually applied: 0.0 (minimum value)
    /// Input:  0.5 → Actually applied: 0.5
    /// Input:  2.0 → Actually applied: 1.0 (maximum value)
    /// ```
    ///
    /// dB (decibel) conversion:
    /// ```
    /// Volume 0.0  = -∞ dB (silence)
    /// Volume 0.1  = -20 dB
    /// Volume 0.5  = -6 dB (half size)
    /// Volume 1.0  = 0 dB (original)
    ///
    /// dB = 20 × log₁₀(volume)
    /// ```
    ///
    /// Meaning of private(set):
    /// ```swift
    /// // Inside class: Read/write possible
    /// self.volume = 0.8  // ✅ OK
    ///
    /// // Outside class: Read only
    /// let vol = player.volume     // ✅ OK (read)
    /// player.volume = 0.8         // ❌ Error (direct write not allowed)
    /// player.setVolume(0.8)       // ✅ OK (write through method)
    /// ```
    private(set) var volume: Float = 1.0

    /// @var isPlaying
    /// @brief Whether audio engine is running
    ///
    /// @details
    /// Flag to check if the engine has been start()ed.
    /// Pause/resume behavior varies depending on this value.
    ///
    /// State transition:
    /// ```
    /// [Stopped] ──start()──▶ [Playing]
    ///              ↑              │
    ///              │              │ pause()
    ///              │              ↓
    ///              └───stop()──[Paused]
    ///                             │
    ///                             │ resume()
    ///                             ↓
    ///                          [Playing]
    /// ```
    private(set) var isPlaying: Bool = false

    /// @var currentFormat
    /// @brief Audio format for the current session
    ///
    /// @details
    /// Set when the first frame is queued, and all subsequent frames must have the same format.
    /// If a frame with a different format arrives, a `formatMismatch` error occurs.
    ///
    /// Format components:
    /// ```
    /// AVAudioFormat {
    ///     sampleRate: 48000.0 Hz
    ///     channels: 2 (stereo)
    ///     commonFormat: .pcmFormatFloat32
    ///     interleaved: false (planar)
    /// }
    /// ```
    ///
    /// Format verification:
    /// ```swift
    /// // First frame
    /// currentFormat = nil
    /// enqueue(frame1)  // Set currentFormat
    ///
    /// // Subsequent frames
    /// enqueue(frame2)  // Compare with currentFormat
    /// - Format matches: ✅ Play
    /// - Format mismatch: ❌ formatMismatch error
    /// ```
    ///
    /// When format change is needed:
    /// ```swift
    /// // When changing video file
    /// player.stop()           // currentFormat = nil
    /// player.start()          // Reset with new format
    /// ```
    ///
    /// nil cases:
    /// - Right after initialization
    /// - After stop() is called
    /// - No frames queued yet
    private var currentFormat: AVAudioFormat?

    /// @var frameQueue
    /// @brief Queue of frames waiting for playback
    ///
    /// @details
    /// Tracks frames added by enqueue().
    /// Removed in onBufferFinished() when frame playback completes.
    ///
    /// Role of the queue:
    /// 1. Buffer tracking: How many frames are currently waiting for playback?
    /// 2. Memory management: Clean up completed frames
    /// 3. Overflow prevention: Check maxQueueSize
    ///
    /// Queue operation example:
    /// ```
    /// Initial: frameQueue = []
    ///
    /// enqueue(frame1) → frameQueue = [frame1]
    /// enqueue(frame2) → frameQueue = [frame1, frame2]
    /// enqueue(frame3) → frameQueue = [frame1, frame2, frame3]
    ///
    /// frame1 playback complete → frameQueue = [frame2, frame3]
    /// frame2 playback complete → frameQueue = [frame3]
    /// frame3 playback complete → frameQueue = []
    /// ```
    ///
    /// Notes:
    /// - This queue is for tracking. Actual playback occurs in AVAudioPlayerNode's internal queue.
    /// - frameQueue.count != actual buffer count in playerNode (slight difference possible)
    private var frameQueue: [AudioFrame] = []

    /// @var queueLock
    /// @brief Lock for frameQueue access
    ///
    /// @details
    /// Prevents simultaneous access to frameQueue from multiple threads.
    ///
    /// Why is Lock needed?
    /// ```
    /// Thread A (decoding thread):
    ///     enqueue() → frameQueue.append()
    ///
    /// Thread B (callback thread):
    ///     onBufferFinished() → frameQueue.remove()
    ///
    /// Thread C (main thread):
    ///     queueSize() → frameQueue.count
    ///
    /// Without Lock: Race Condition! (data corruption, crash)
    /// With Lock: Only one thread accesses at a time ✅
    /// ```
    ///
    /// NSLock usage:
    /// ```swift
    /// queueLock.lock()         // 🔒 Lock (other threads wait)
    /// frameQueue.append(frame) // Safe modification
    /// queueLock.unlock()       // 🔓 Unlock (other threads can enter)
    /// ```
    ///
    /// Safe pattern using defer:
    /// ```swift
    /// func queueSize() -> Int {
    ///     queueLock.lock()
    ///     defer { queueLock.unlock() }  // Auto-release on function exit
    ///     return frameQueue.count
    ///     // defer ensures unlock before return
    /// }
    /// ```
    ///
    /// Lock vs DispatchQueue:
    /// ```
    /// NSLock:
    /// ✅ Fast (low-level lock)
    /// ✅ Simple usage
    /// ❌ Deadlock caution needed
    ///
    /// DispatchQueue (Serial):
    /// ✅ Less deadlock risk
    /// ✅ GCD integration
    /// ❌ Slightly slower (context switching)
    ///
    /// NSLock chosen here for performance
    /// ```
    private let queueLock = NSLock()

    /// @var maxQueueSize
    /// @brief Maximum queue size (number of frames)
    ///
    /// @details
    /// Maximum number of frames that can be stored in the queue.
    /// If this value is exceeded, new frames are silently discarded (skipped).
    ///
    /// Why 30?
    /// ```
    /// 1 frame = 1024 samples / 48000 Hz ≈ 21ms
    /// 30 frames = 30 × 21ms = 630ms (0.63 seconds)
    ///
    /// Advantages:
    /// - Sufficient buffer: Absorbs decoding delays
    /// - Smooth playback: Prevents underrun
    ///
    /// Disadvantages:
    /// - Memory usage: 30 × 8KB = 240KB (acceptable level)
    /// - Increased latency: Maximum 630ms (affects video sync)
    /// ```
    ///
    /// Buffer size tuning guide:
    /// ```
    /// Small value (e.g., 5):
    /// ✅ Low latency (105ms)
    /// ❌ Risk of audio stuttering (underrun)
    ///
    /// Large value (e.g., 100):
    /// ✅ Very stable
    /// ❌ High latency (2100ms = 2.1 seconds)
    /// ❌ Memory waste (800KB)
    ///
    /// Medium value (30):
    /// ✅ Balanced choice ⭐
    /// ```
    ///
    /// Overflow behavior:
    /// ```swift
    /// enqueue(frame31)  // Queue is full
    /// → guard queueSize < maxQueueSize else { return }
    /// → Frame discarded (silently skipped)
    /// → No error, no log
    ///
    /// Result: Some audio missing (but crash prevented)
    /// ```
    private let maxQueueSize = 30

    // MARK: - Initialization

    /// @brief Initialize AudioPlayer
    ///
    /// @details
    /// Sets up AVAudioEngine, AVAudioPlayerNode, AVAudioMixerNode and
    /// connects nodes to the engine.
    ///
    /// Initialization steps:
    /// ```
    /// 1. Create AVAudioEngine
    /// 2. Create AVAudioPlayerNode
    /// 3. Get MixerNode (engine.mainMixerNode)
    /// 4. Connect PlayerNode to Engine (attach)
    /// ```
    ///
    /// Note: Node connections are NOT made at this stage!
    /// Actual connections occur in setupAudioSession() when the first frame is queued.
    ///
    /// ## State after initialization
    /// ```
    /// AudioEngine: Created, stopped state
    /// PlayerNode: Created, not connected
    /// MixerNode: Ready
    /// currentFormat: nil
    /// frameQueue: []
    /// isPlaying: false
    /// ```
    init() {
        // Create AVAudioEngine
        audioEngine = AVAudioEngine()

        // Create PlayerNode (for PCM buffer playback)
        playerNode = AVAudioPlayerNode()

        // Get MixerNode (for volume control)
        // mainMixerNode is automatically provided by AVAudioEngine
        mixer = audioEngine.mainMixerNode

        // Add PlayerNode to Engine
        // Note: Not yet connected to mixer!
        // Connection happens in setupAudioSession()
        audioEngine.attach(playerNode)

        // Reason: Need to know audio format to connect
        // Format is determined when first frame is queued
    }

    /// @brief Destructor (called when memory is released)
    ///
    /// @details
    /// Automatically called when AudioPlayer object is removed from memory.
    /// Cleans up audio engine to prevent resource leaks.
    ///
    /// Cleanup sequence:
    /// ```
    /// 1. playerNode.stop() → Stop playback
    /// 2. audioEngine.stop() → Terminate engine
    /// 3. frameQueue.removeAll() → Clear queue
    /// 4. currentFormat = nil → Reset format
    /// ```
    ///
    /// Why is this needed?
    /// ```swift
    /// // ARC (Automatic Reference Counting):
    /// var player: AudioPlayer? = AudioPlayer()
    /// try player?.start()
    /// player = nil  // ← deinit called!
    ///
    /// Without deinit:
    /// → audioEngine.stop() not called
    /// → Continues running in background
    /// → CPU/memory waste
    /// ```
    ///
    /// Auto-call timing:
    /// ```swift
    /// class VideoPlayer {
    ///     let audioPlayer = AudioPlayer()
    ///     // ...
    /// }  // ← audioPlayer.deinit automatically called when VideoPlayer is destroyed
    /// ```
    deinit {
        stop()  // Perform all cleanup operations
    }

    // MARK: - Public Methods

    /// @brief Start audio engine
    ///
    /// @throws AudioPlayerError.engineStartFailed Engine start failed
    ///
    /// @details
    /// Starts AVAudioEngine to complete audio playback preparation.
    /// If this method is not called, no sound will be produced even if frames are queued!
    ///
    /// Operation:
    /// ```
    /// 1. If engine already running, early return (prevent duplicate start)
    /// 2. audioEngine.start() → Start engine
    /// 3. playerNode.play() → Switch PlayerNode to playback mode
    /// 4. isPlaying = true → Update state
    /// ```
    ///
    /// Engine start process:
    /// ```
    /// audioEngine.start():
    /// - Initialize audio hardware
    /// - Set buffer size (default: ~512 samples)
    /// - Negotiate sample rate (typically 48kHz)
    /// - Initialize Audio Unit
    ///
    /// Time taken: Typically 10~50ms
    /// ```
    ///
    /// ## Error cases
    /// ```
    /// 1. No audio device (headless server)
    /// 2. Audio device in use (monopolized by other app)
    /// 3. No permission (sandbox constraints)
    /// 4. Insufficient system resources
    /// ```
    func start() throws {
        // Prevent duplicate start
        guard !audioEngine.isRunning else { return }

        do {
            // Start AVAudioEngine
            // - Initialize audio hardware
            // - Allocate buffers
            // - Set sample rate
            try audioEngine.start()

            // Start PlayerNode playback
            // Note: Actual sound requires adding buffers with scheduleBuffer()
            playerNode.play()

            // Update state
            isPlaying = true

        } catch {
            // Wrap with our own error on start failure
            throw AudioPlayerError.engineStartFailed(error)
        }
    }

    /// @brief Stop and clean up audio engine
    ///
    /// @details
    /// Completely stops playback and clears all queues.
    /// Must call start() to play again.
    ///
    /// Stop sequence:
    /// ```
    /// 1. playerNode.stop() → Stop playback, clear internal queue
    /// 2. audioEngine.stop() → Terminate engine, release hardware
    /// 3. isPlaying = false → Update state
    /// 4. currentFormat = nil → Reset format
    /// 5. frameQueue.removeAll() → Clear tracking queue
    /// ```
    ///
    /// pause() vs stop() difference:
    /// ```
    /// pause():
    /// - Engine continues running
    /// - Queue retained
    /// - Can resume immediately with resume()
    ///
    /// stop():
    /// - Engine completely terminated
    /// - Queue cleared
    /// - Need to queue again after start()
    /// ```
    ///
    /// Memory cleanup:
    /// ```
    /// Before stop():
    /// - frameQueue: [frame1, frame2, ..., frame30] (240KB)
    /// - playerNode internal queue: Several MB
    ///
    /// After stop():
    /// - frameQueue: [] (nearly 0KB)
    /// - playerNode internal queue: Released
    /// ```
    func stop() {
        // Stop PlayerNode (internal queue also cleared)
        playerNode.stop()

        // Stop AudioEngine (release hardware)
        audioEngine.stop()

        // Update state
        isPlaying = false

        // Reset format (allow new format on next start)
        currentFormat = nil

        // Clear tracking queue (thread-safe)
        queueLock.lock()
        frameQueue.removeAll()
        queueLock.unlock()
    }

    /// @brief Pause audio playback
    ///
    /// @details
    /// Pauses while maintaining current playback position and queue.
    /// Calling resume() will resume from exactly where it paused.
    ///
    /// Operation:
    /// ```
    /// playerNode.pause():
    /// - Remember current buffer playback position
    /// - Retain remaining buffers in queue
    /// - Only stop audio output
    ///
    /// Engine continues running!
    /// ```
    ///
    /// Internal state:
    /// ```
    /// Before pause():
    /// [Buf1▶][Buf2][Buf3][Buf4]
    ///   ↑ Playing (50% position)
    ///
    /// After pause():
    /// [Buf1⏸][Buf2][Buf3][Buf4]
    ///   ↑ Paused (remembers 50% position)
    ///
    /// After resume():
    /// [Buf1▶][Buf2][Buf3][Buf4]
    ///   ↑ Resume from 50%
    /// ```
    func pause() {
        // Pause PlayerNode
        // Note: Engine continues running
        playerNode.pause()

        // Update state
        isPlaying = false
    }

    /// @brief Resume paused audio playback
    ///
    /// @details
    /// Continues playback paused by pause() from exactly where it stopped.
    ///
    /// Operation:
    /// ```
    /// playerNode.play():
    /// - Resume from remembered playback position
    /// - Play buffers in queue in order
    /// ```
    ///
    /// Note: No effect if engine has been stop()ped!
    /// ```swift
    /// player.stop()    // Terminate engine
    /// player.resume()  // ❌ No effect! Need start()
    /// ```
    func resume() {
        // Resume PlayerNode playback
        playerNode.play()

        // Update state
        isPlaying = true
    }

    /// @brief Add audio frame to playback queue
    ///
    /// @param frame Audio frame to play
    ///
    /// @throws AudioPlayerError.bufferConversionFailed Buffer conversion failed
    /// @throws AudioPlayerError.formatMismatch Audio format mismatch
    ///
    /// @details
    /// Converts AudioFrame decoded by FFmpeg to AVAudioPCMBuffer and
    /// adds it to PlayerNode's playback queue. This method is thread-safe.
    ///
    /// Processing flow:
    /// ```
    /// 1. Check queue size (max 30)
    /// 2. Convert AudioFrame → AVAudioPCMBuffer
    /// 3. If first frame, call setupAudioSession()
    /// 4. Verify format match
    /// 5. Call playerNode.scheduleBuffer()
    /// 6. Add to frameQueue (for tracking)
    /// ```
    ///
    /// Buffer conversion process:
    /// ```
    /// AudioFrame (FFmpeg):
    /// - format: .floatPlanar
    /// - data: Data (raw bytes)
    /// - sampleCount: 1024
    ///
    ///      ↓ frame.toAudioBuffer()
    ///
    /// AVAudioPCMBuffer (Apple):
    /// - format: AVAudioFormat
    /// - floatChannelData: UnsafeMutablePointer
    /// - frameLength: 1024
    /// ```
    ///
    /// Scheduling:
    /// ```
    /// playerNode.scheduleBuffer(buffer) { [weak self] in
    ///     // Called when this buffer playback completes
    ///     self?.onBufferFinished(frame)
    /// }
    ///
    /// Calling thread: AVAudioEngine internal thread
    /// Calling time: Right after last sample of buffer is played
    /// ```
    ///
    /// Reason for [weak self]:
    /// ```
    /// Prevent strong reference cycle:
    ///
    /// AudioPlayer → scheduleBuffer → closure → self (strong) → AudioPlayer
    /// └───────────────────────────────────────────────────────────────┘
    ///                     ↑ Retain cycle! Memory leak!
    ///
    /// Using [weak self]:
    /// AudioPlayer → scheduleBuffer → closure → self (weak) → AudioPlayer
    ///                                               ↓
    ///                                              nil (when AudioPlayer released)
    /// ```
    func enqueue(_ frame: AudioFrame) throws {
        // Step 1: Check queue size (thread-safe)
        queueLock.lock()
        let queueSize = frameQueue.count
        queueLock.unlock()

        // Prevent overflow: Skip if queue is full
        guard queueSize < maxQueueSize else {
            // Return silently (frame discarded)
            return
        }

        // Step 2: Convert to AVAudioPCMBuffer
        guard let buffer = frame.toAudioBuffer() else {
            // Conversion failed (invalid format, out of memory, etc.)
            throw AudioPlayerError.bufferConversionFailed
        }

        // Step 3: If first frame, set up audio session
        if currentFormat == nil {
            // Remember format (for comparison with subsequent frames)
            currentFormat = buffer.format

            // Connect nodes: playerNode → mixer
            setupAudioSession(format: buffer.format)
        }

        // Step 4: Verify format match
        guard buffer.format == currentFormat else {
            // Error if format differs
            // Example: First frame 48kHz, second frame 44.1kHz
            throw AudioPlayerError.formatMismatch
        }

        // Step 5: Schedule buffer to PlayerNode
        playerNode.scheduleBuffer(buffer) { [weak self] in
            // This closure is called when buffer playback completes
            // Calling thread: AVAudioEngine internal thread

            // [weak self]: AudioPlayer may already be released
            self?.onBufferFinished(frame)
        }

        // Step 6: Add to tracking queue (thread-safe)
        queueLock.lock()
        frameQueue.append(frame)
        queueLock.unlock()
    }

    /// @brief Set volume
    ///
    /// @param volume Volume level (0.0 ~ 1.0)
    ///
    /// @details
    /// Adjusts audio output volume in range 0.0 (silence) ~ 1.0 (maximum).
    /// Values outside the range are automatically clamped.
    ///
    /// Clamping:
    /// ```
    /// Input → Actually applied
    /// -5.0 → 0.0 (minimum value)
    ///  0.3 → 0.3 (as is)
    ///  2.0 → 1.0 (maximum value)
    /// ```
    ///
    /// Volume scale:
    /// ```
    /// 0.0 = Silence (mute)
    /// 0.5 = 50% volume (approximately -6dB)
    /// 1.0 = 100% volume (original, 0dB)
    /// ```
    ///
    /// Immediate application:
    /// ```
    /// setVolume(0.8)
    /// → self.volume = 0.8
    /// → mixer.outputVolume = 0.8
    /// → Immediately reflected in playing audio (smoothly)
    /// ```
    func setVolume(_ volume: Float) {
        // Validate and clamp value
        // max(0.0, min(1.0, volume)):
        // 1. min(1.0, volume) → 1.0 if greater than 1.0
        // 2. max(0.0, ...) → 0.0 if less than 0.0
        self.volume = max(0.0, min(1.0, volume))

        // Apply immediately to MixerNode
        mixer.outputVolume = self.volume
    }

    /// @brief Remove all frames in queue
    ///
    /// @details
    /// Clears both PlayerNode's playback queue and tracking queue.
    /// Called during seek operation to clean up previous audio.
    ///
    /// Operation:
    /// ```
    /// 1. playerNode.stop() → Stop playback, clear internal queue
    /// 2. frameQueue.removeAll() → Clear tracking queue
    /// 3. If was playing, playerNode.play() → Restore playback mode
    /// ```
    ///
    /// Clear queue without stopping playback:
    /// ```
    /// Before flush():
    /// [Playing▶][Buf2][Buf3]...[Buf30]
    ///
    /// During flush():
    /// playerNode.stop() → Remove all
    /// frameQueue.removeAll()
    ///
    /// After flush():
    /// [] ← Empty queue
    /// playerNode.play() ← Playback mode (no buffers)
    /// ```
    func flush() {
        // Stop PlayerNode (internal queue also cleared)
        playerNode.stop()

        // Clear tracking queue (thread-safe)
        queueLock.lock()
        frameQueue.removeAll()
        queueLock.unlock()

        // Restore playback mode if was playing
        if isPlaying {
            playerNode.play()
        }

        // Note: No sound unless new frames are enqueue()d
    }

    /// @brief Query current queue size
    ///
    /// @return Number of frames in queue (0 ~ maxQueueSize)
    ///
    /// @details
    /// Returns the number of frames waiting for playback.
    /// This value is useful for monitoring buffering status.
    ///
    /// Safe unlock using defer:
    /// ```swift
    /// func queueSize() -> Int {
    ///     queueLock.lock()
    ///     defer { queueLock.unlock() }  // Auto-release on function exit
    ///
    ///     return frameQueue.count
    ///     // defer block executes before return → unlock guaranteed
    /// }
    /// ```
    ///
    /// Implementation without defer?
    /// ```swift
    /// // ❌ Risky code
    /// func queueSize() -> Int {
    ///     queueLock.lock()
    ///     let count = frameQueue.count
    ///     queueLock.unlock()  // Deadlock if forgotten!
    ///     return count
    /// }
    /// ```
    func queueSize() -> Int {
        queueLock.lock()
        defer { queueLock.unlock() }  // Guarantee auto-release
        return frameQueue.count
    }

    // MARK: - Private Methods

    /// @brief Set up audio session (connect nodes)
    ///
    /// @param format Audio format (sample rate, channels, bit depth)
    ///
    /// @details
    /// Completes audio pipeline by connecting PlayerNode and MixerNode.
    /// This method is automatically called when the first frame is queued.
    ///
    /// Connection process:
    /// ```
    /// audioEngine.connect(
    ///     source: playerNode,    // PCM buffer playback
    ///     destination: mixer,    // Volume control
    ///     format: audioFormat    // 48kHz stereo, etc.
    /// )
    ///
    /// Result:
    /// [PlayerNode] ───format──▶ [MixerNode] ───▶ 🔊
    /// ```
    ///
    /// Role of format:
    /// ```
    /// format specified:
    /// - PlayerNode and MixerNode communicate with same format
    /// - Sample rate match (48kHz)
    /// - Channel count match (2 channels)
    /// - Bit depth match (Float32)
    ///
    /// format = nil:
    /// - Automatic format negotiation (not recommended)
    /// ```
    ///
    /// Volume initialization:
    /// ```
    /// mixer.outputVolume = self.volume
    /// → User may have called setVolume() before start()
    /// → Apply saved volume value
    /// ```
    private func setupAudioSession(format: AVAudioFormat) {
        // Connect PlayerNode to Mixer
        // Now buffers added with playerNode.scheduleBuffer()
        // will be output to speaker through mixer.
        audioEngine.connect(playerNode, to: mixer, format: format)

        // Apply initial volume
        // (user may have called setVolume() before start())
        mixer.outputVolume = volume
    }

    /// @brief Buffer playback completion callback
    ///
    /// @param frame Frame whose playback completed
    ///
    /// @details
    /// Called as completion handler of playerNode.scheduleBuffer().
    /// Removes completed frame from tracking queue.
    ///
    /// Call timing:
    /// ```
    /// Right after last sample of buffer is output to speaker
    ///
    /// Timeline:
    /// [Frame1 playback] ─────▶ Last sample ─▶ onBufferFinished(Frame1) called
    /// ```
    ///
    /// Calling thread: AVAudioEngine internal thread (not main thread!)
    ///
    /// Queue cleanup:
    /// ```
    /// frameQueue = [Frame1, Frame2, Frame3]
    ///                 ↑ Playback complete
    ///
    /// onBufferFinished(Frame1) called
    /// → firstIndex(where: { $0 == Frame1 }) → 0
    /// → frameQueue.remove(at: 0)
    ///
    /// frameQueue = [Frame2, Frame3]
    /// ```
    ///
    /// Safe unlock using defer:
    /// ```swift
    /// queueLock.lock()
    /// defer { queueLock.unlock() }  // Auto-release on function exit
    ///
    /// // Complex logic...
    /// if condition { return }  // ← defer guarantees unlock
    /// // ...
    /// // End of function ← defer guarantees unlock
    /// ```
    private func onBufferFinished(_ frame: AudioFrame) {
        queueLock.lock()
        defer { queueLock.unlock() }

        // Find and remove completed frame from queue
        if let index = frameQueue.firstIndex(where: { $0 == frame }) {
            frameQueue.remove(at: index)
        }

        // Note: May not find index (when flush() is called)
        // In this case, silently ignore (no error)
    }
}

// MARK: - Error Types

/// @enum AudioPlayerError
/// @brief AudioPlayer error type
///
/// @details
/// Defines errors that can occur in AudioPlayer.
/// Implements LocalizedError protocol to provide user-friendly error messages.
///
/// ## Error types
/// ```
/// 1. engineStartFailed: Engine start failed
///    - Cause: No audio device, no permission, insufficient resources
///
/// 2. bufferConversionFailed: Buffer conversion failed
///    - Cause: Invalid AudioFrame format, out of memory
///
/// 3. formatMismatch: Audio format mismatch
///    - Cause: Queuing frame with different format than first frame
/// ```
enum AudioPlayerError: LocalizedError {
    /// @var engineStartFailed
    /// @brief Audio engine start failure
    ///
    /// @param error Original error
    ///
    /// @details
    /// Wraps error that occurred when calling AVAudioEngine.start().
    ///
    /// Common causes:
    /// - No audio output device (headless server)
    /// - Audio device monopolized by another app
    /// - Insufficient sandbox permissions
    /// - Insufficient system resources
    case engineStartFailed(Error)

    /// @var bufferConversionFailed
    /// @brief Audio buffer conversion failure
    ///
    /// @details
    /// Error that occurred while converting AudioFrame to AVAudioPCMBuffer.
    ///
    /// Common causes:
    /// - AudioFrame format is invalid (unsupported format)
    /// - Out of memory (buffer allocation failed)
    /// - AudioFrame.data is corrupted
    case bufferConversionFailed

    /// @var formatMismatch
    /// @brief Audio format mismatch
    ///
    /// @details
    /// Occurs when format of frame being queued differs from currentFormat.
    ///
    /// Example:
    /// ```
    /// Frame1: 48000 Hz, 2 channels, Float32 ✅
    /// Frame2: 44100 Hz, 2 channels, Float32 ❌ formatMismatch!
    /// ```
    ///
    /// Solution:
    /// ```swift
    /// // Restart player when format changes
    /// audioPlayer.stop()
    /// try audioPlayer.start()
    /// try audioPlayer.enqueue(newFormatFrame)
    /// ```
    case formatMismatch

    /// @brief User-friendly error description
    ///
    /// @return Error description string
    ///
    /// @details
    /// Returns description string for each error case.
    /// Provides message to display to user in UI.
    var errorDescription: String? {
        switch self {
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .bufferConversionFailed:
            return "Failed to convert audio frame to buffer"
        case .formatMismatch:
            return "Audio format mismatch"
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Integration Guide: AudioPlayer Usage Flow
// ═══════════════════════════════════════════════════════════════════════════
//
// 1️⃣ Initialize and start
// ────────────────────────────────────────────────
// let audioPlayer = AudioPlayer()
// try audioPlayer.start()  // Start engine
//
// 2️⃣ Frame queuing (decoding loop)
// ────────────────────────────────────────────────
// for frame in decoder.decodeAudio() {
//     try audioPlayer.enqueue(frame)
//     // Automatically played through speaker
// }
//
// 3️⃣ Playback control (user input)
// ────────────────────────────────────────────────
// // Pause
// audioPlayer.pause()
//
// // Resume
// audioPlayer.resume()
//
// // Volume control
// audioPlayer.setVolume(0.7)  // 70%
//
// 4️⃣ Seek handling
// ────────────────────────────────────────────────
// // User moves timeline
// decoder.seek(to: 60.0)       // Move to 60 seconds
// audioPlayer.flush()          // Remove previous audio
// // Start queuing frames from new 60-second position
//
// 5️⃣ Shutdown and cleanup
// ────────────────────────────────────────────────
// audioPlayer.stop()  // Terminate engine, clear queue
//
// ═══════════════════════════════════════════════════════════════════════════
