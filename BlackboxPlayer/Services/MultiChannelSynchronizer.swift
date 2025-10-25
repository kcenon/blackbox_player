/// @file MultiChannelSynchronizer.swift
/// @brief Multi-channel video synchronization coordinator
/// @author BlackboxPlayer Development Team
/// @details
/// This file defines a class that synchronizes multiple camera channels of a dashcam.
/// Since dashcams typically record simultaneously from front/rear/left/right cameras,
/// all channels must display the same time during playback.

import Foundation

/// @enum SyncError
/// @brief Synchronization errors
enum SyncError: Error {
    case channelNotFound(String)
    case decoderNotInitialized(String)
    case seekFailed(String)
    case unknown(String)
}

/// @class MultiChannelSynchronizer
/// @brief Class that synchronizes multiple video channels.
///
/// @details
/// ## Key features:
/// - Manage multiple VideoDecoder instances
/// - Maintain master timeline
/// - Synchronize all channels to the same timestamp
/// - Apply play/pause/seek to all channels simultaneously
///
/// ## Usage example:
/// ```swift
/// let sync = MultiChannelSynchronizer()
/// sync.addChannel(id: "front", decoder: frontDecoder)
/// sync.addChannel(id: "rear", decoder: rearDecoder)
///
/// // Move all channels to 30 seconds
/// try sync.seekAll(to: 30.0)
///
/// // Get next frame from all channels
/// let frames = try sync.stepForwardAll()
/// ```
class MultiChannelSynchronizer {

    // MARK: - Properties

    /// @var channels
    /// @brief Dictionary of VideoDecoder by channel
    /// @details
    /// - Key: Channel ID (e.g. "front", "rear", "left", "right", "interior")
    /// - Value: VideoDecoder instance
    private var channels: [String: VideoDecoder] = [:]

    /// @var masterTimestamp
    /// @brief Current timestamp of master timeline
    /// @details
    /// - All channels synchronized to this time
    /// - Operates based on this value during play/seek
    private(set) var masterTimestamp: TimeInterval = 0

    /// @var isPlaying
    /// @brief Whether playing
    private(set) var isPlaying: Bool = false

    /// @var tolerance
    /// @brief Synchronization tolerance (in seconds)
    /// @details
    /// - Considered synchronized if timestamp difference between channels is below this value
    /// - Default value: 0.033s (Approximately 1 frame at 30fps)
    private let tolerance: TimeInterval = 0.033

    /// @var autoCorrectionThreshold
    /// @brief Auto-correction threshold (in seconds)
    /// @details
    /// - Automatically correct when drift exceeds this value
    /// - Default value: 0.050s (50ms, Approximately 1.5 frames)
    private let autoCorrectionThreshold: TimeInterval = 0.050

    /// @var monitoringEnabled
    /// @brief Whether drift monitoring is enabled
    private var monitoringEnabled: Bool = false

    /// @var monitoringTimer
    /// @brief Drift monitoring timer
    private var monitoringTimer: Timer?

    /// @var driftHistory
    /// @brief Drift history (for statistics)
    /// @details
    /// - Store last 100 drift values
    /// - Used for average and maximum calculations
    private var driftHistory: [TimeInterval] = []

    /// @var maxDriftHistorySize
    /// @brief Maximum drift history size
    private let maxDriftHistorySize = 100

    // MARK: - Initialization

    /// @brief Create synchronization object.
    init() {
        // No initialization logic
    }

    // MARK: - Channel Management

    /// @brief Add channel.
    ///
    /// @param id Channel ID (e.g. "front", "rear")
    /// @param decoder VideoDecoder instance
    ///
    /// @details
    /// Calling multiple times with same ID overwrites existing channel.
    func addChannel(id: String, decoder: VideoDecoder) {
        channels[id] = decoder
    }

    /// @brief Remove channel.
    ///
    /// @param id Channel ID to remove
    func removeChannel(id: String) {
        channels.removeValue(forKey: id)
    }

    /// @brief Remove all channels.
    func removeAllChannels() {
        channels.removeAll()
    }

    /// @brief Return list of registered channel IDs.
    ///
    /// @return Array of channel IDs
    func getChannelIDs() -> [String] {
        return Array(channels.keys)
    }

    /// @brief Get decoder for specific channel.
    ///
    /// @param id Channel ID
    /// @return VideoDecoder instance, nil if none
    func getDecoder(for id: String) -> VideoDecoder? {
        return channels[id]
    }

    // MARK: - Synchronization

    /// @brief Move all channels to specific time.
    ///
    /// @param timestamp Time to move to (in seconds)
    ///
    /// @throws SyncError
    ///
    /// @details
    /// Seek all channels simultaneously to same timestamp.
    /// Throws error if any fails.
    func seekAll(to timestamp: TimeInterval) throws {
        // Seek all channels to specified time
        for (channelID, decoder) in channels {
            do {
                try decoder.seek(to: timestamp)
            } catch {
                throw SyncError.seekFailed("Failed to seek channel '\(channelID)': \(error)")
            }
        }

        // Update master timestamp
        masterTimestamp = timestamp
    }

    /// @brief Move all channels to specific frame number.
    ///
    /// @param frameNumber Frame number to move to
    ///
    /// @throws SyncError
    ///
    /// @details
    /// Since each channel may have different frame rate,
    /// convert frame number to timestamp for synchronization.
    func seekAllToFrame(_ frameNumber: Int) throws {
        // Calculate timestamp based on first channel's frame rate
        guard let firstDecoder = channels.values.first,
              let videoInfo = firstDecoder.videoInfo else {
            throw SyncError.decoderNotInitialized("No initialized decoder found")
        }

        let timestamp = Double(frameNumber) / videoInfo.frameRate
        try seekAll(to: timestamp)
    }

    /// @brief Move to next frame of all channels.
    ///
    /// @return Dictionary of video frames by channel
    ///
    /// @throws SyncError
    ///
    /// @details
    /// Decode and return next video frame from each channel.
    /// Master timestamp is updated based on fastest channel.
    func stepForwardAll() throws -> [String: VideoFrame] {
        var frames: [String: VideoFrame] = [:]
        var maxTimestamp: TimeInterval = masterTimestamp

        // Get next frame from each channel
        for (channelID, decoder) in channels {
            if let frame = try decoder.stepForward() {
                frames[channelID] = frame
                maxTimestamp = max(maxTimestamp, frame.timestamp)
            }
        }

        // Update master timestamp
        masterTimestamp = maxTimestamp

        return frames
    }

    /// @brief Move to previous frame of all channels.
    ///
    /// @throws SyncError
    ///
    /// @details
    /// Move each channel to previous frame.
    /// May not go back exactly 1 frame since it's seek-based.
    func stepBackwardAll() throws {
        // Move all channels to previous frame
        for (channelID, decoder) in channels {
            do {
                try decoder.stepBackward()
            } catch {
                throw SyncError.seekFailed("Failed to step backward on channel '\(channelID)': \(error)")
            }
        }

        // Update master timestamp (based on first channel)
        if let firstDecoder = channels.values.first {
            masterTimestamp = firstDecoder.getCurrentTimestamp()
        }
    }

    /// @brief Return current master timestamp.
    ///
    /// @return Current timestamp (in seconds)
    func getCurrentTimestamp() -> TimeInterval {
        return masterTimestamp
    }

    /// @brief Check if all channels are synchronized.
    ///
    /// @return True if timestamp difference of all channels is within tolerance
    ///
    /// @details
    /// By comparing currentTimestamp of each channel
    /// check if maximum difference is within tolerance.
    func isSynchronized() -> Bool {
        guard !channels.isEmpty else { return true }

        let timestamps = channels.values.map { $0.getCurrentTimestamp() }
        guard let minTimestamp = timestamps.min(),
              let maxTimestamp = timestamps.max() else {
            return false
        }

        let difference = maxTimestamp - minTimestamp
        return difference <= tolerance
    }

    // MARK: - Playback Control

    /// @brief Start playback.
    ///
    /// @details
    /// Actual frame decoding must be performed in external timer or loop.
    /// This method only changes playback state.
    func play() {
        isPlaying = true
    }

    /// @brief Pause playback.
    func pause() {
        isPlaying = false
    }

    /// @brief Stop playback and return to beginning.
    ///
    /// @throws SyncError
    func stop() throws {
        isPlaying = false
        try seekAll(to: 0)
    }

    // MARK: - Information

    /// @brief Return status of all channels as string.
    ///
    /// @return Timestamp information by channel
    ///
    /// @details
    /// Output current timestamp of each channel for debugging.
    func getStatusString() -> String {
        var status = "Master: \(String(format: "%.3f", masterTimestamp))s\n"
        status += "Channels:\n"

        for (channelID, decoder) in channels.sorted(by: { $0.key < $1.key }) {
            let timestamp = decoder.getCurrentTimestamp()
            let diff = abs(timestamp - masterTimestamp)
            status += "  \(channelID): \(String(format: "%.3f", timestamp))s (diff: \(String(format: "%.3f", diff))s)\n"
        }

        status += "Synchronized: \(isSynchronized())"

        // Add drift statistics
        if !driftHistory.isEmpty {
            let avgDrift = driftHistory.reduce(0, +) / Double(driftHistory.count)
            let maxDrift = driftHistory.max() ?? 0
            status += "\nDrift Stats: Avg=\(String(format: "%.3f", avgDrift * 1000))ms, Max=\(String(format: "%.3f", maxDrift * 1000))ms"
        }

        return status
    }

    // MARK: - Drift Monitoring

    /// @brief Start drift monitoring.
    ///
    /// @param interval Monitoring interval (in seconds), default 0.1s (100ms)
    ///
    /// @details
    /// Periodically check synchronization status between channels,
    /// automatically correct when drift exceeds threshold.
    ///
    /// How it works:
    /// 1. Execute timer at specified intervals
    /// 2. Check timestamps of all channels
    /// 3. Calculate maximum drift
    /// 4. Auto-correct when exceeding threshold
    /// 5. Record in drift history
    func startMonitoring(interval: TimeInterval = 0.1) {
        guard !monitoringEnabled else { return }

        monitoringEnabled = true

        // Execute timer on main thread (allows UI updates)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.monitorSync()
        }
    }

    /// @brief Stop drift monitoring.
    func stopMonitoring() {
        monitoringEnabled = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    /// @brief Monitor synchronization status and correct if needed.
    ///
    /// @details
    /// Monitoring process:
    /// 1. Collect current timestamp of each channel
    /// 2. Calculate difference from master timestamp
    /// 3. Check maximum drift
    /// 4. threshold sand when correctDrift() Call
    /// 5. Record in drift history
    func monitorSync() {
        guard !channels.isEmpty else { return }

        // Collect timestamps of all channels
        let timestamps = channels.values.map { $0.getCurrentTimestamp() }
        guard let minTimestamp = timestamps.min(),
              let maxTimestamp = timestamps.max() else {
            return
        }

        // Calculate maximum drift
        let maxDrift = maxTimestamp - minTimestamp

        // Record in drift history
        driftHistory.append(maxDrift)
        if driftHistory.count > maxDriftHistorySize {
            driftHistory.removeFirst()
        }

        // Auto-correct when exceeding threshold
        if maxDrift > autoCorrectionThreshold {
            do {
                try correctDrift(maxDrift: maxDrift)
            } catch {
                print("Drift correction failed: \(error)")
            }
        }
    }

    /// @brief Automatically correct drift.
    ///
    /// @param maxDrift Current maximum drift
    ///
    /// @throws SyncError
    ///
    /// @details
    /// Correction strategy:
    /// 1. Find slowest channel (channel with smallest timestamp)
    /// 2. Find fastest channel (channel with largest timestamp)
    /// 3. Set median value as target timestamp
    /// 4. Seek all channels to target timestamp
    ///
    /// Reason for using median:
    /// - Move all channels by same amount
    /// - Minimize number of seeks
    /// - Minimize playback interruptions
    func correctDrift(maxDrift: TimeInterval) throws {
        guard !channels.isEmpty else { return }

        // Collect timestamps of all channels
        var channelTimestamps: [(id: String, timestamp: TimeInterval)] = []
        for (id, decoder) in channels {
            let timestamp = decoder.getCurrentTimestamp()
            channelTimestamps.append((id: id, timestamp: timestamp))
        }

        // Sort
        channelTimestamps.sort { $0.timestamp < $1.timestamp }

        guard let slowest = channelTimestamps.first,
              let fastest = channelTimestamps.last else {
            return
        }

        // Calculate median
        let targetTimestamp = (slowest.timestamp + fastest.timestamp) / 2.0

        print("Correcting drift: \(String(format: "%.3f", maxDrift * 1000))ms -> Seeking to \(String(format: "%.3f", targetTimestamp))s")

        // Move all channels to target timestamp
        for (id, decoder) in channels {
            let currentTimestamp = decoder.getCurrentTimestamp()
            let diff = abs(currentTimestamp - targetTimestamp)

            // Correct only channels with large drift (ignore small drift)
            if diff > tolerance {
                do {
                    try decoder.seek(to: targetTimestamp)
                } catch {
                    throw SyncError.seekFailed("Failed to correct drift for channel '\(id)': \(error)")
                }
            }
        }

        // Update master timestamp
        masterTimestamp = targetTimestamp
    }

    /// @brief Return drift statistics.
    ///
    /// @return (Average drift, maximum drift, history count)
    ///
    /// @details
    /// Statistics information:
    /// - average: Average drift (in seconds)
    /// - maximum: Maximum drift (in seconds)
    /// - count: Number of samples recorded in history
    func getDriftStatistics() -> (average: TimeInterval, maximum: TimeInterval, count: Int) {
        guard !driftHistory.isEmpty else {
            return (0, 0, 0)
        }

        let average = driftHistory.reduce(0, +) / Double(driftHistory.count)
        let maximum = driftHistory.max() ?? 0

        return (average, maximum, driftHistory.count)
    }

    /// @brief Initialize drift history.
    func clearDriftHistory() {
        driftHistory.removeAll()
    }
}
