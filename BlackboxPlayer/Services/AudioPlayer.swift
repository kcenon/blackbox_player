//
//  AudioPlayer.swift
//  BlackboxPlayer
//
//  AVAudioEngine-based audio player for decoded audio frames
//

import Foundation
import AVFoundation

/// Audio player that uses AVAudioEngine to play decoded audio frames
class AudioPlayer {
    // MARK: - Properties

    /// Audio engine
    private let audioEngine: AVAudioEngine

    /// Audio player node
    private let playerNode: AVAudioPlayerNode

    /// Mixer node for volume control
    private let mixer: AVAudioMixerNode

    /// Current volume (0.0 to 1.0)
    private(set) var volume: Float = 1.0

    /// Whether the audio engine is running
    private(set) var isPlaying: Bool = false

    /// Audio format for the current session
    private var currentFormat: AVAudioFormat?

    /// Frame buffer queue
    private var frameQueue: [AudioFrame] = []
    private let queueLock = NSLock()

    /// Maximum queue size
    private let maxQueueSize = 30

    // MARK: - Initialization

    init() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixer = audioEngine.mainMixerNode

        // Attach player node
        audioEngine.attach(playerNode)
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Start audio engine
    /// - Throws: Error if engine fails to start
    func start() throws {
        guard !audioEngine.isRunning else { return }

        do {
            try audioEngine.start()
            playerNode.play()
            isPlaying = true
        } catch {
            throw AudioPlayerError.engineStartFailed(error)
        }
    }

    /// Stop audio engine
    func stop() {
        playerNode.stop()
        audioEngine.stop()
        isPlaying = false
        currentFormat = nil

        queueLock.lock()
        frameQueue.removeAll()
        queueLock.unlock()
    }

    /// Pause audio playback
    func pause() {
        playerNode.pause()
        isPlaying = false
    }

    /// Resume audio playback
    func resume() {
        playerNode.play()
        isPlaying = true
    }

    /// Queue audio frame for playback
    /// - Parameter frame: Audio frame to play
    /// - Throws: AudioPlayerError if frame cannot be queued
    func enqueue(_ frame: AudioFrame) throws {
        // Check queue size
        queueLock.lock()
        let queueSize = frameQueue.count
        queueLock.unlock()

        guard queueSize < maxQueueSize else {
            // Queue is full, skip this frame
            return
        }

        // Convert to audio buffer
        guard let buffer = frame.toAudioBuffer() else {
            throw AudioPlayerError.bufferConversionFailed
        }

        // Initialize audio format if needed
        if currentFormat == nil {
            currentFormat = buffer.format
            setupAudioSession(format: buffer.format)
        }

        // Ensure format matches
        guard buffer.format == currentFormat else {
            throw AudioPlayerError.formatMismatch
        }

        // Schedule buffer for playback
        playerNode.scheduleBuffer(buffer) { [weak self] in
            self?.onBufferFinished(frame)
        }

        // Add to queue
        queueLock.lock()
        frameQueue.append(frame)
        queueLock.unlock()
    }

    /// Set volume
    /// - Parameter volume: Volume level (0.0 to 1.0)
    func setVolume(_ volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
        mixer.outputVolume = self.volume
    }

    /// Flush all queued audio frames
    func flush() {
        playerNode.stop()

        queueLock.lock()
        frameQueue.removeAll()
        queueLock.unlock()

        if isPlaying {
            playerNode.play()
        }
    }

    /// Get current queue size
    /// - Returns: Number of frames in queue
    func queueSize() -> Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return frameQueue.count
    }

    // MARK: - Private Methods

    private func setupAudioSession(format: AVAudioFormat) {
        // Connect player node to mixer
        audioEngine.connect(playerNode, to: mixer, format: format)

        // Set initial volume
        mixer.outputVolume = volume
    }

    private func onBufferFinished(_ frame: AudioFrame) {
        queueLock.lock()
        defer { queueLock.unlock() }

        // Remove finished frame from queue
        if let index = frameQueue.firstIndex(where: { $0 == frame }) {
            frameQueue.remove(at: index)
        }
    }
}

// MARK: - Error Types

enum AudioPlayerError: LocalizedError {
    case engineStartFailed(Error)
    case bufferConversionFailed
    case formatMismatch

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
