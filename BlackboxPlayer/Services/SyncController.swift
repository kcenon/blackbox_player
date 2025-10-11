//
//  SyncController.swift
//  BlackboxPlayer
//
//  Synchronization controller for multi-channel playback
//

import Foundation
import Combine
import QuartzCore

/// Controller for synchronizing multiple video channels
class SyncController: ObservableObject {
    // MARK: - Published Properties

    /// Playback state
    @Published private(set) var playbackState: PlaybackState = .stopped

    /// Current playback time (synchronized across all channels)
    @Published private(set) var currentTime: TimeInterval = 0.0

    /// Playback position (0.0 to 1.0)
    @Published private(set) var playbackPosition: Double = 0.0

    /// Playback speed
    @Published var playbackSpeed: Double = 1.0

    /// Is buffering
    @Published private(set) var isBuffering: Bool = false

    // MARK: - Properties

    /// Video channels
    private var channels: [VideoChannel] = []

    /// GPS service for location data
    private(set) var gpsService: GPSService = GPSService()

    /// G-Sensor service for acceleration data
    private(set) var gsensorService: GSensorService = GSensorService()

    /// Lock for thread-safe access to channels array
    private let channelsLock = NSLock()

    /// Total duration (from longest channel)
    private(set) var duration: TimeInterval = 0.0

    /// Master clock reference time
    private var masterClockStartTime: CFTimeInterval = 0.0

    /// Playback start time (video time when play started)
    private var playbackStartTime: TimeInterval = 0.0

    /// Sync timer
    private var syncTimer: Timer?

    /// Drift threshold (milliseconds)
    private let driftThreshold: TimeInterval = 0.050 // 50ms

    /// Sync check interval
    private let syncCheckInterval: TimeInterval = 0.1 // 100ms

    /// Target frame rate for sync updates
    private let targetFrameRate: Double = 30.0

    // MARK: - Initialization

    init() {
        // Empty initialization
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Load video file with multiple channels
    /// - Parameter videoFile: VideoFile with multiple channels
    /// - Throws: ChannelError if initialization fails
    func loadVideoFile(_ videoFile: VideoFile) throws {
        // Stop current playback
        stop()

        // Create channels
        var newChannels: [VideoChannel] = []

        for channelInfo in videoFile.channels where channelInfo.isEnabled {
            let channel = VideoChannel(channelInfo: channelInfo)
            try channel.initialize()
            newChannels.append(channel)
        }

        guard !newChannels.isEmpty else {
            throw ChannelError.invalidState("No enabled channels found")
        }

        channelsLock.lock()
        self.channels = newChannels
        channelsLock.unlock()

        // Calculate total duration (use longest channel)
        self.duration = videoFile.duration

        // Load GPS and G-Sensor data
        gpsService.loadGPSData(from: videoFile.metadata, startTime: videoFile.timestamp)
        gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)

        // Reset playback state
        currentTime = 0.0
        playbackPosition = 0.0
        playbackState = .paused
    }

    /// Start synchronized playback
    func play() {
        guard playbackState != .playing else { return }

        channelsLock.lock()
        let isEmpty = channels.isEmpty
        let channelsCopy = channels
        channelsLock.unlock()

        guard !isEmpty else {
            warningLog("[SyncController] Cannot play: no channels loaded")
            return
        }

        infoLog("[SyncController] Starting playback with \(channelsCopy.count) channels")

        // Start all channels decoding
        for channel in channelsCopy {
            infoLog("[SyncController] Starting decoding for channel: \(channel.channelInfo.position.displayName)")
            channel.startDecoding()
        }

        // Set master clock reference
        masterClockStartTime = CACurrentMediaTime()
        playbackStartTime = currentTime

        playbackState = .playing

        // Start sync timer
        startSyncTimer()
    }

    /// Pause synchronized playback
    func pause() {
        guard playbackState == .playing else { return }

        playbackState = .paused
        stopSyncTimer()
    }

    /// Toggle play/pause
    func togglePlayPause() {
        if playbackState == .playing {
            pause()
        } else {
            play()
        }
    }

    /// Stop playback and reset
    func stop() {
        stopSyncTimer()

        channelsLock.lock()
        let channelsCopy = channels
        channels.removeAll()
        channelsLock.unlock()

        for channel in channelsCopy {
            channel.stop()
        }

        // Clear GPS and G-Sensor data
        gpsService.clear()
        gsensorService.clear()

        playbackState = .stopped
        currentTime = 0.0
        playbackPosition = 0.0
        duration = 0.0
    }

    /// Seek all channels to specific time
    /// - Parameter time: Target time in seconds
    func seekToTime(_ time: TimeInterval) {
        let clampedTime = max(0.0, min(duration, time))

        // Pause playback during seek
        let wasPlaying = playbackState == .playing
        if wasPlaying {
            pause()
        }

        // Seek all channels
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        for channel in channelsCopy {
            do {
                try channel.seek(to: clampedTime)
            } catch {
                print("Failed to seek channel \(channel.channelInfo.position.displayName): \(error)")
            }
        }

        currentTime = clampedTime
        playbackPosition = duration > 0 ? clampedTime / duration : 0.0

        // Update GPS and G-Sensor services at new position
        gpsService.getCurrentLocation(at: clampedTime)
        gsensorService.getCurrentAcceleration(at: clampedTime)

        // Resume if was playing
        if wasPlaying {
            play()
        }
    }

    /// Seek by relative time
    /// - Parameter seconds: Seconds to seek (positive = forward, negative = backward)
    func seekBySeconds(_ seconds: Double) {
        seekToTime(currentTime + seconds)
    }

    /// Get synchronized frames for all channels at current time
    /// - Returns: Dictionary mapping channel position to frame
    func getSynchronizedFrames() -> [CameraPosition: VideoFrame] {
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        var frames: [CameraPosition: VideoFrame] = [:]

        for channel in channelsCopy {
            if let frame = channel.getFrame(at: currentTime) {
                frames[channel.channelInfo.position] = frame
            }
        }

        return frames
    }

    /// Get buffer status for all channels
    /// - Returns: Dictionary mapping channel position to buffer status
    func getBufferStatus() -> [CameraPosition: (current: Int, max: Int, fillPercentage: Double)] {
        channelsLock.lock()
        let channelsCopy = channels
        channelsLock.unlock()

        var status: [CameraPosition: (current: Int, max: Int, fillPercentage: Double)] = [:]

        for channel in channelsCopy {
            status[channel.channelInfo.position] = channel.getBufferStatus()
        }

        return status
    }

    /// Get channel count
    var channelCount: Int {
        channelsLock.lock()
        defer { channelsLock.unlock() }
        return channels.count
    }

    /// Check if all channels are ready
    var allChannelsReady: Bool {
        channelsLock.lock()
        defer { channelsLock.unlock() }
        return !channels.isEmpty && channels.allSatisfy { $0.state == .ready || $0.state == .decoding }
    }

    // MARK: - Private Methods

    private func startSyncTimer() {
        stopSyncTimer()

        let interval = 1.0 / targetFrameRate

        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateSync()
        }
    }

    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func updateSync() {
        guard playbackState == .playing else { return }

        // Calculate current time from master clock
        let elapsedTime = CACurrentMediaTime() - masterClockStartTime
        let videoTime = playbackStartTime + (elapsedTime * playbackSpeed)

        // Update current time
        currentTime = videoTime
        playbackPosition = duration > 0 ? currentTime / duration : 0.0

        // Update GPS and G-Sensor services
        gpsService.getCurrentLocation(at: currentTime)
        gsensorService.getCurrentAcceleration(at: currentTime)

        // Check if reached end
        if currentTime >= duration {
            stop()
            currentTime = duration
            playbackPosition = 1.0
            return
        }

        // Check drift and correct if needed
        checkAndCorrectDrift()

        // Check buffer status
        checkBufferStatus()
    }

    private func checkAndCorrectDrift() {
        // Get frames from all channels
        let frames = getSynchronizedFrames()

        // Calculate drift for each channel
        for (position, frame) in frames {
            let drift = abs(frame.timestamp - currentTime)

            if drift > driftThreshold {
                print("Channel \(position.displayName) drift detected: \(Int(drift * 1000))ms")

                // For now, just log drift
                // In production, implement frame skip/wait logic
                // If drift is too large, could seek the channel
            }
        }
    }

    private func checkBufferStatus() {
        let bufferStatus = getBufferStatus()

        // Check if any channel has low buffer
        let isAnyBufferLow = bufferStatus.values.contains { status in
            status.fillPercentage < 0.2 // Less than 20% full
        }

        if isAnyBufferLow && !isBuffering {
            print("Warning: Low buffer detected in some channels")
            isBuffering = true
        } else if !isAnyBufferLow && isBuffering {
            isBuffering = false
        }
    }
}

// MARK: - Computed Properties

extension SyncController {
    /// Current time as formatted string (MM:SS)
    var currentTimeString: String {
        return formatTime(currentTime)
    }

    /// Duration as formatted string (MM:SS)
    var durationString: String {
        return formatTime(duration)
    }

    /// Remaining time as formatted string (MM:SS)
    var remainingTimeString: String {
        let remaining = max(0, duration - currentTime)
        return "-\(formatTime(remaining))"
    }

    /// Playback speed as formatted string
    var playbackSpeedString: String {
        return String(format: "%.1fx", playbackSpeed)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
