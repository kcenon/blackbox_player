//
//  VideoPlayerViewModel.swift
//  BlackboxPlayer
//
//  ViewModel for video player state management
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for managing video player state
class VideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current playback state
    @Published var playbackState: PlaybackState = .stopped

    /// Current playback position (0.0 to 1.0)
    @Published var playbackPosition: Double = 0.0

    /// Current time in seconds
    @Published var currentTime: TimeInterval = 0.0

    /// Total duration in seconds
    @Published var duration: TimeInterval = 0.0

    /// Current video frame
    @Published var currentFrame: VideoFrame?

    /// Playback speed (0.5x, 1.0x, 2.0x)
    @Published var playbackSpeed: Double = 1.0

    /// Volume (0.0 to 1.0)
    @Published var volume: Double = 1.0

    /// Is buffering
    @Published var isBuffering: Bool = false

    /// Error message
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var decoder: VideoDecoder?
    private var videoFile: VideoFile?
    private var playbackTimer: Timer?
    private var targetFrameRate: Double = 30.0

    // MARK: - Initialization

    init() {
        // Empty initialization
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Load video file
    /// - Parameter videoFile: Video file to load
    func loadVideo(_ videoFile: VideoFile) {
        stop()

        self.videoFile = videoFile

        // Get front camera file path (or first available channel)
        guard let frontChannel = videoFile.channel(for: .front) ?? videoFile.channels.first else {
            errorMessage = "No video channel available"
            return
        }

        // Create decoder
        let decoder = VideoDecoder(filePath: frontChannel.filePath)

        do {
            try decoder.initialize()
            self.decoder = decoder

            // Set duration
            if let videoDuration = decoder.getDuration() {
                self.duration = videoDuration
            } else {
                self.duration = videoFile.duration
            }

            // Get video info
            if let videoInfo = decoder.videoInfo {
                self.targetFrameRate = videoInfo.frameRate
            }

            // Load first frame
            loadFrameAt(time: 0)

            playbackState = .paused
            errorMessage = nil

        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
            playbackState = .stopped
        }
    }

    /// Start or resume playback
    func play() {
        guard playbackState != .playing, decoder != nil else { return }

        playbackState = .playing
        startPlaybackTimer()
    }

    /// Pause playback
    func pause() {
        guard playbackState == .playing else { return }

        playbackState = .paused
        stopPlaybackTimer()
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
        stopPlaybackTimer()
        playbackState = .stopped
        currentTime = 0.0
        playbackPosition = 0.0
        currentFrame = nil
        decoder = nil
        videoFile = nil
    }

    /// Seek to specific position
    /// - Parameter position: Position (0.0 to 1.0)
    func seek(to position: Double) {
        let clampedPosition = max(0.0, min(1.0, position))
        let targetTime = clampedPosition * duration

        seekToTime(targetTime)
    }

    /// Seek to specific time
    /// - Parameter time: Time in seconds
    func seekToTime(_ time: TimeInterval) {
        guard let decoder = decoder else { return }

        let clampedTime = max(0.0, min(duration, time))

        do {
            try decoder.seek(to: clampedTime)
            currentTime = clampedTime
            playbackPosition = duration > 0 ? clampedTime / duration : 0.0

            // Load frame at new position
            loadFrameAt(time: clampedTime)

        } catch {
            errorMessage = "Seek failed: \(error.localizedDescription)"
        }
    }

    /// Step forward one frame
    func stepForward() {
        let frameTime = 1.0 / targetFrameRate
        seekToTime(currentTime + frameTime)
    }

    /// Step backward one frame
    func stepBackward() {
        let frameTime = 1.0 / targetFrameRate
        seekToTime(currentTime - frameTime)
    }

    /// Set playback speed
    /// - Parameter speed: Playback speed (0.5x, 1.0x, 2.0x, etc.)
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = max(0.1, min(4.0, speed))

        // Restart timer with new speed if playing
        if playbackState == .playing {
            stopPlaybackTimer()
            startPlaybackTimer()
        }
    }

    /// Set volume
    /// - Parameter volume: Volume (0.0 to 1.0)
    func setVolume(_ volume: Double) {
        self.volume = max(0.0, min(1.0, volume))
        // TODO: Apply volume to audio playback
    }

    // MARK: - Private Methods

    private func startPlaybackTimer() {
        stopPlaybackTimer()

        let interval = (1.0 / targetFrameRate) / playbackSpeed

        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updatePlayback() {
        guard let decoder = decoder else {
            stop()
            return
        }

        do {
            // Decode next frame
            if let result = try decoder.decodeNextFrame() {
                if let videoFrame = result.video {
                    currentFrame = videoFrame
                    currentTime = videoFrame.timestamp
                    playbackPosition = duration > 0 ? currentTime / duration : 0.0
                }
            } else {
                // End of file reached
                stop()
                currentTime = duration
                playbackPosition = 1.0
            }
        } catch {
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

    private func loadFrameAt(time: TimeInterval) {
        guard let decoder = decoder else { return }

        isBuffering = true

        // Seek and decode one frame
        do {
            try decoder.seek(to: time)

            // Decode next frame
            if let result = try decoder.decodeNextFrame(),
               let videoFrame = result.video {
                currentFrame = videoFrame
            }

            isBuffering = false
        } catch {
            errorMessage = "Failed to load frame: \(error.localizedDescription)"
            isBuffering = false
        }
    }
}

// MARK: - Supporting Types

/// Playback state
enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused

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

extension VideoPlayerViewModel {
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

    /// Playback speed as formatted string (e.g., "1.0x")
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
