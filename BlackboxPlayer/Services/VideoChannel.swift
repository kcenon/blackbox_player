//
//  VideoChannel.swift
//  BlackboxPlayer
//
//  Video channel for multi-channel synchronized playback
//

import Foundation
import Combine

/// Video channel managing independent decoder and frame buffer
class VideoChannel {
    // MARK: - Properties

    /// Channel identifier
    let channelID: UUID

    /// Channel information
    let channelInfo: ChannelInfo

    /// Channel state
    @Published private(set) var state: ChannelState = .idle

    /// Current frame
    @Published private(set) var currentFrame: VideoFrame?

    /// Video decoder
    private var decoder: VideoDecoder?

    /// Frame buffer (circular buffer)
    private var frameBuffer: [VideoFrame] = []
    private let maxBufferSize = 30

    /// Decoding queue
    private let decodingQueue: DispatchQueue

    /// Buffer lock
    private let bufferLock = NSLock()

    /// Is decoding
    private var isDecoding = false

    /// Target frame time (for synchronization)
    private var targetFrameTime: TimeInterval = 0.0

    // MARK: - Initialization

    init(channelID: UUID = UUID(), channelInfo: ChannelInfo) {
        self.channelID = channelID
        self.channelInfo = channelInfo
        self.decodingQueue = DispatchQueue(
            label: "com.blackboxplayer.channel.\(channelID.uuidString)",
            qos: .userInitiated
        )
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Initialize channel and decoder
    /// - Throws: DecoderError if initialization fails
    func initialize() throws {
        guard state == .idle else {
            throw ChannelError.invalidState("Channel already initialized")
        }

        let decoder = VideoDecoder(filePath: channelInfo.filePath)
        try decoder.initialize()
        self.decoder = decoder

        state = .ready
    }

    /// Start decoding frames in background
    func startDecoding() {
        guard state == .ready, !isDecoding else { return }

        isDecoding = true
        state = .decoding

        decodingQueue.async { [weak self] in
            self?.decodingLoop()
        }
    }

    /// Stop decoding and cleanup
    func stop() {
        isDecoding = false
        state = .idle

        bufferLock.lock()
        frameBuffer.removeAll()
        bufferLock.unlock()

        decoder = nil
        currentFrame = nil
    }

    /// Seek to specific time
    /// - Parameter time: Target time in seconds
    /// - Throws: DecoderError if seek fails
    func seek(to time: TimeInterval) throws {
        guard let decoder = decoder else {
            throw ChannelError.notInitialized
        }

        // Pause decoding
        let wasDecoding = isDecoding
        isDecoding = false

        // Clear buffer
        bufferLock.lock()
        frameBuffer.removeAll()
        bufferLock.unlock()

        // Seek decoder
        try decoder.seek(to: time)
        targetFrameTime = time

        // Resume decoding
        if wasDecoding {
            startDecoding()
        }

        state = .ready
    }

    /// Get frame closest to target time
    /// - Parameter time: Target time in seconds
    /// - Returns: VideoFrame if available
    func getFrame(at time: TimeInterval) -> VideoFrame? {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // Find frame closest to target time
        guard !frameBuffer.isEmpty else { return nil }

        let closestFrame = frameBuffer.min { frame1, frame2 in
            abs(frame1.timestamp - time) < abs(frame2.timestamp - time)
        }

        // Remove frames older than current time minus 1 second (keep recent history for seeking)
        let cleanupThreshold = time - 1.0
        frameBuffer.removeAll { $0.timestamp < cleanupThreshold }

        return closestFrame
    }

    /// Get buffer status
    /// - Returns: Tuple of (current size, max size, fill percentage)
    func getBufferStatus() -> (current: Int, max: Int, fillPercentage: Double) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let current = frameBuffer.count
        let percentage = Double(current) / Double(maxBufferSize)
        return (current, maxBufferSize, percentage)
    }

    /// Flush frame buffer
    func flushBuffer() {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        frameBuffer.removeAll()
    }

    // MARK: - Private Methods

    private func decodingLoop() {
        infoLog("[VideoChannel:\(channelInfo.position.displayName)] Decoding loop started")
        var frameCount = 0
        var lastLogTime = Date()

        while isDecoding {
            autoreleasepool {
                // Check buffer size
                bufferLock.lock()
                let bufferSize = frameBuffer.count
                bufferLock.unlock()

                // If buffer is full, wait
                guard bufferSize < maxBufferSize else {
                    // Log buffer full status every 2 seconds
                    if Date().timeIntervalSince(lastLogTime) > 2.0 {
                        debugLog("[VideoChannel:\(channelInfo.position.displayName)] Buffer full (\(bufferSize)/\(maxBufferSize)), waiting...")
                        lastLogTime = Date()
                    }
                    Thread.sleep(forTimeInterval: 0.01) // 10ms
                    return  // Exit autoreleasepool, continue while loop
                }

                // Decode next frame
                do {
                    guard let decoder = decoder else {
                        isDecoding = false
                        return
                    }

                    if let result = try decoder.decodeNextFrame() {
                        if let videoFrame = result.video {
                            addFrameToBuffer(videoFrame)
                            frameCount += 1
                        }
                        // Skip audio frames in multi-channel (audio from master channel only)
                    }
                    // If result is nil, decoder needs more packets (EAGAIN) - continue loop
                } catch {
                    errorLog("Channel \(channelInfo.position.displayName) decode error: \(error)")
                    if case DecoderError.endOfFile = error {
                        isDecoding = false
                        state = .completed
                        infoLog("Channel \(channelInfo.position.displayName) completed after \(frameCount) frames")
                    } else if case DecoderError.readFrameError(let code) = error, code == -541478725 {
                        // AVERROR_EOF from av_read_frame
                        isDecoding = false
                        state = .completed
                        infoLog("Channel \(channelInfo.position.displayName) completed (EOF) after \(frameCount) frames")
                    } else {
                        state = .error(error.localizedDescription)
                        isDecoding = false
                    }
                }
            }
        }
        infoLog("[VideoChannel:\(channelInfo.position.displayName)] Decoding loop ended, total frames: \(frameCount)")
    }

    private func addFrameToBuffer(_ frame: VideoFrame) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // Add to buffer
        frameBuffer.append(frame)

        // Sort by timestamp
        frameBuffer.sort { $0.timestamp < $1.timestamp }

        // Remove old frames if buffer exceeds max size
        if frameBuffer.count > maxBufferSize {
            frameBuffer.removeFirst(frameBuffer.count - maxBufferSize)
        }

        // Log first few frames
        if frameBuffer.count <= 3 {
            debugLog("[VideoChannel:\(channelInfo.position.displayName)] Buffered frame #\(frame.frameNumber) at \(String(format: "%.2f", frame.timestamp))s, buffer size: \(frameBuffer.count)")
        }

        // Update current frame
        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = frame
        }
    }
}

// MARK: - Supporting Types

/// Channel state
enum ChannelState: Equatable {
    case idle
    case ready
    case decoding
    case completed
    case error(String)

    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .ready:
            return "Ready"
        case .decoding:
            return "Decoding"
        case .completed:
            return "Completed"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

/// Channel errors
enum ChannelError: LocalizedError {
    case notInitialized
    case invalidState(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Channel not initialized"
        case .invalidState(let message):
            return "Invalid channel state: \(message)"
        }
    }
}

// MARK: - Equatable

extension VideoChannel: Equatable {
    static func == (lhs: VideoChannel, rhs: VideoChannel) -> Bool {
        return lhs.channelID == rhs.channelID
    }
}

// MARK: - Identifiable

extension VideoChannel: Identifiable {
    var id: UUID { channelID }
}
