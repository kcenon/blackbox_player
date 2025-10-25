/// @file VideoDecoder.swift
/// @brief FFmpeg-based video/audio decoder
/// @author BlackboxPlayer Development Team
/// @details
/// This file defines a class that decodes video and audio using the FFmpeg library.
/// FFmpeg is a powerful multimedia framework written in C.

import Foundation       // Swift fundamental types (String, Data, etc.)
import CoreGraphics     // Graphics-related types (CGSize, CGRect, etc.)

/// @class VideoDecoder
/// @brief Class for decoding dashcam video files.
///
/// @details
/// ## Main Features:
/// - H.264 video decoding (converting compressed video to displayable format)
/// - MP3 audio decoding (converting compressed audio to playable format)
/// - Video seeking (jumping to specific time)
/// - Frame-by-frame decoding (extracting video frames one at a time)
///
/// ## What is Decoding?
/// - The process of decompressing compressed video files (e.g., MP4) into a format that can be displayed on screen
/// - Example: H.264 compressed data → RGB pixel data
///
/// ## Usage Example:
/// ```swift
/// let decoder = VideoDecoder(filePath: "/path/to/video.mp4")
/// try decoder.initialize()
///
/// while let frames = try decoder.decodeNextFrame() {
///     if let videoFrame = frames.video {
///         // Process video frame
///     }
/// }
/// ```
class VideoDecoder {

    // MARK: - Properties
    // Variables that store the class's data

    // ============================================
    // MARK: File Information
    // ============================================

    /// @var filePath
    /// @brief Path to the video file to decode
    /// @details
    /// - Example: "/Users/username/Videos/blackbox.mp4"
    /// - private: Cannot be modified externally (set only during initialization)
    private let filePath: String

    // ============================================
    // MARK: FFmpeg Context
    // ============================================

    /*
     What is FFmpeg "Context"?
     - Structure containing all information and state needed for decoding
     - Written in C language, accessed via pointers in Swift
     - UnsafeMutablePointer: Type for using C pointers in Swift
     */

    /// @var formatContext
    /// @brief FormatContext - Container holding file's overall structure information
    /// @details
    /// - Which streams exist (video, audio, subtitles, etc.)
    /// - What file format it is (MP4, AVI, MKV, etc.)
    /// - Total playback duration
    /// - Optional(?): nil before initialization (unset state)
    private var formatContext: UnsafeMutablePointer<AVFormatContext>?

    /// @var videoCodecContext
    /// @brief Video Codec Context - Video decoding information
    /// @details
    /// - Codec: Compression/decompression method (H.264, H.265, etc.)
    /// - Resolution (width, height)
    /// - Frame rate (frames per second)
    /// - Pixel format (YUV420P, RGB, etc.)
    private var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?

    /// @var audioCodecContext
    /// @brief Audio Codec Context - Audio decoding information
    /// @details
    /// - Sample rate (44100Hz, 48000Hz, etc.)
    /// - Number of channels (mono=1, stereo=2)
    /// - Audio format (PCM, AAC, etc.)
    private var audioCodecContext: UnsafeMutablePointer<AVCodecContext>?

    /// @var scalerContext
    /// @brief Scaler Context - Pixel format converter
    /// @details
    /// - SwScale (Software Scale): FFmpeg component for pixel format conversion
    /// - Example: YUV420P (video encoding standard) → BGRA (for display)
    /// - Resolution changes also possible (e.g., 1080p → 720p)
    private var scalerContext: UnsafeMutablePointer<SwsContext>?

    // ============================================
    // MARK: Stream Indices
    // ============================================

    /*
     What is a Stream?
     - Video files contain multiple independent data flows
     - Example: Stream#0=video, Stream#1=audio, Stream#2=subtitles
     - Each stream has a unique index number
     */

    /// @var videoStreamIndex
    /// @brief Index number of the video stream
    /// @details
    /// - -1: Not found yet (initial value)
    /// - 0 or above: Index of found video stream
    private var videoStreamIndex: Int = -1

    /// @var audioStreamIndex
    /// @brief Index number of the audio stream
    /// @details
    /// - -1: Not found yet or no audio
    /// - 0 or above: Index of found audio stream
    private var audioStreamIndex: Int = -1

    // ============================================
    // MARK: Decoding State
    // ============================================

    /// @var frameNumber
    /// @brief Current decoded frame number
    /// @details
    /// - Starts from 0 and increments by 1
    /// - Used for debugging and progress tracking
    /// - private(set): Readable externally, not modifiable
    private(set) var frameNumber: Int = 0

    /// @var currentTimestamp
    /// @brief Current frame's timestamp (in seconds)
    /// @details
    /// - Time of last decoded frame
    /// - Used for seeking and synchronization
    private(set) var currentTimestamp: TimeInterval = 0

    /// @var isInitialized
    /// @brief Whether decoder is initialized
    /// @details
    /// - false: initialize() not called yet
    /// - true: initialize() complete, decoding possible
    /// - private(set): Readable externally, not modifiable
    private(set) var isInitialized: Bool = false

    // ============================================
    // MARK: Stream Information
    // ============================================

    /// @var videoInfo
    /// @brief Detailed information of video stream
    /// @details
    /// - Optional(?): nil before initialization
    /// - VideoStreamInfo struct contains resolution, frame rate, etc.
    private(set) var videoInfo: VideoStreamInfo?

    /// @var audioInfo
    /// @brief Detailed information of audio stream
    /// @details
    /// - Optional(?): nil if no audio
    /// - AudioStreamInfo struct contains sample rate, channel count, etc.
    private(set) var audioInfo: AudioStreamInfo?

    // ============================================
    // MARK: Thread Safety
    // ============================================

    /// @var decoderLock
    /// @brief Lock ensuring thread safety of decoder operations
    /// @details
    /// - Concurrent seek and decoding can cause EXC_BAD_ACCESS
    /// - NSLock prevents concurrent access
    private let decoderLock = NSLock()

    // MARK: - Initialization

    /// @brief Creates decoder object.
    ///
    /// @param filePath Full path to video file to decode
    ///
    /// @details
    /// Notes:
    /// - This method only creates the object, does not prepare for actual decoding
    /// - Must call `initialize()` method to start decoding
    ///
    /// Example:
    /// ```swift
    /// let decoder = VideoDecoder(filePath: "/path/to/video.mp4")
    /// // Not yet ready to decode
    /// try decoder.initialize()  // Now ready to decode
    /// ```
    init(filePath: String) {
        self.filePath = filePath
    }

    /// @brief Automatically called when object is deallocated from memory.
    ///
    /// @details
    /// Preventing memory leaks:
    /// - FFmpeg's C library does not use Swift's automatic memory management (ARC)
    /// - Therefore, memory must be manually released
    /// - Calls cleanup() to clean up all FFmpeg resources
    deinit {
        cleanup()
    }

    // MARK: - Public Methods
    // Methods that can be called externally

    /// @brief Initializes the decoder and opens the video file.
    ///
    /// @details
    /// Initialization process:
    /// 1. Check file existence
    /// 2. Open file with FFmpeg
    /// 3. Find video/audio streams
    /// 4. Initialize decoder for each stream
    ///
    /// @throws DecoderError
    ///   - `.alreadyInitialized`: Already initialized
    ///   - `.cannotOpenFile`: Cannot open file
    ///   - `.cannotFindStreamInfo`: Cannot find stream information
    ///   - `.noVideoStream`: No video stream
    ///
    /// Usage example:
    /// ```swift
    /// do {
    ///     try decoder.initialize()
    ///     print("Decoder initialized successfully!")
    /// } catch {
    ///     print("Initialization failed: \(error)")
    /// }
    /// ```
    func initialize() throws {
        // 1. Prevent duplicate initialization
        // - Re-initializing already initialized decoder can cause memory leaks
        guard !isInitialized else {
            throw DecoderError.alreadyInitialized
        }

        // 2. Check file existence
        // - FileManager: iOS/macOS file system manager
        // - fileExists(atPath:): Check if file exists at path
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DecoderError.cannotOpenFile("File not found: \(filePath)")
        }

        // 3. Open file with FFmpeg
        // withCString: Convert Swift String to C string (char*)
        // - FFmpeg is a C library so C string is required
        // - cString can only be used inside the closure (memory safety)
        var formatCtx: UnsafeMutablePointer<AVFormatContext>?
        let openResult = filePath.withCString { cString in
            // avformat_open_input: FFmpeg function, opens file and reads format info
            // &formatCtx: Pointer to variable to store result
            // nil: No specific format (auto-detect)
            // nil: No additional options
            return avformat_open_input(&formatCtx, cString, nil, nil)
        }

        // 4. Check file open result
        // - FFmpeg functions return 0 on success, negative error code on failure
        if openResult != 0 {
            // Convert error message to human-readable format
            var errorBuffer = [Int8](repeating: 0, count: 256)  // C string buffer
            av_strerror(openResult, &errorBuffer, 256)  // Convert error code to string
            let errorString = String(cString: errorBuffer)  // Convert to Swift String
            throw DecoderError.cannotOpenFile("Failed to open \(filePath): \(errorString)")
        }
        self.formatContext = formatCtx

        // 5. Find stream information
        // avformat_find_stream_info: Analyze file to extract stream info
        // - Determines video/audio codec, resolution, sample rate, etc.
        // - Returns negative value on failure
        if avformat_find_stream_info(formatContext, nil) < 0 {
            cleanup()  // Clean up memory on failure
            throw DecoderError.cannotFindStreamInfo(filePath)
        }

        // 6. Verify format context safety
        guard let formatCtx = formatContext else {
            throw DecoderError.cannotOpenFile(filePath)
        }

        // 7. Search all streams in file
        // nb_streams: Number of streams
        let numStreams = Int(formatCtx.pointee.nb_streams)
        let streams = formatCtx.pointee.streams  // Stream array

        // Iterate through each stream to find video/audio streams
        for i in 0..<numStreams {
            guard let stream = streams?[i] else { continue }

            // codecpar: Codec parameters (resolution, sample rate, etc.)
            let codecType = stream.pointee.codecpar.pointee.codec_type

            // Find video stream
            if codecType == AVMEDIA_TYPE_VIDEO && videoStreamIndex == -1 {
                videoStreamIndex = i
                try initializeVideoStream(stream: stream)
            }
            // Find audio stream
            else if codecType == AVMEDIA_TYPE_AUDIO && audioStreamIndex == -1 {
                audioStreamIndex = i
                try initializeAudioStream(stream: stream)
            }
        }

        // 8. Verify required streams
        // - At least video stream is required
        // - Audio is optional (video without audio can be played)
        guard videoStreamIndex >= 0 else {
            cleanup()
            throw DecoderError.noVideoStream
        }

        // 9. Mark initialization complete
        isInitialized = true
    }

    /// @brief Decodes the next frame.
    ///
    /// @details
    /// Decoding process:
    /// 1. Read compressed packet from file
    /// 2. Check if packet is video or audio
    /// 3. Decompress with appropriate decoder
    /// 4. Return frame data
    ///
    /// @return (video: VideoFrame?, audio: AudioFrame?) tuple
    ///   - If video frame, data in video, audio is nil
    ///   - If audio frame, data in audio, video is nil
    ///   - Returns nil when end of file is reached
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: Not initialized
    ///   - `.readFrameError`: Frame read failure
    ///   - Other decoding-related errors
    ///
    /// Usage example:
    /// ```swift
    /// while let frames = try decoder.decodeNextFrame() {
    ///     if let videoFrame = frames.video {
    ///         print("Video frame: \(videoFrame.timestamp) seconds")
    ///     }
    ///     if let audioFrame = frames.audio {
    ///         print("Audio frame: \(audioFrame.timestamp) seconds")
    ///     }
    /// }
    /// print("End of file")
    /// ```
    func decodeNextFrame() throws -> (video: VideoFrame?, audio: AudioFrame?)? {
        // Prevent concurrent access with lock
        decoderLock.lock()
        defer { decoderLock.unlock() }

        // 1. Check initialization
        guard isInitialized else {
            throw DecoderError.notInitialized
        }

        guard let formatCtx = formatContext else {
            throw DecoderError.notInitialized
        }

        // 2. Allocate packet memory
        // Packet: Small piece of compressed data
        // - Video/audio data is stored in packet units
        // - Decoding each packet produces one or more frames
        guard let packet = av_packet_alloc() else {
            throw DecoderError.cannotAllocatePacket
        }
        var packetPtr: UnsafeMutablePointer<AVPacket>? = packet
        // defer: Automatically executed when function ends (memory cleanup)
        defer { av_packet_free(&packetPtr) }

        // 3. Read next packet from file
        let readResult = av_read_frame(formatCtx, packet)

        // 4. Check end of file (EOF)
        // -541478725: AVERROR_EOF error code
        if readResult == -541478725 {
            return nil  // No more data to read
        } else if readResult < 0 {
            throw DecoderError.readFrameError(readResult)
        }

        // 5. Check packet stream type
        // stream_index: Which stream this packet came from
        let streamIndex = Int(packet.pointee.stream_index)

        // 6. Decode according to stream type
        if streamIndex == videoStreamIndex {
            // Decode video packet
            let videoFrame = try decodeVideoPacket(packet: packet)
            return (video: videoFrame, audio: nil)
        } else if streamIndex == audioStreamIndex {
            // Decode audio packet
            let audioFrame = try decodeAudioPacket(packet: packet)
            return (video: nil, audio: audioFrame)
        }

        // 7. Unknown stream (subtitles, etc.)
        // - Ignore and move to next packet
        return (video: nil, audio: nil)
    }

    /// @brief Seeks to a specific time position.
    ///
    /// @param timestamp Time to seek to (in seconds)
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: Not initialized
    ///   - `.unknown`: Seek failed
    ///
    /// @details
    /// What is Seek?
    /// - Function to quickly move to a specific point in video
    /// - Example: Jump from 10 seconds to 60 seconds
    ///
    /// What is a Keyframe?
    /// - Frame that can be decoded independently
    /// - Start decoding from keyframe for accurate seeking
    /// - AVSEEK_FLAG_BACKWARD: Move to keyframe before target time
    ///
    /// Usage example:
    /// ```swift
    /// try decoder.seek(to: 30.0)  // Seek to 30 second position
    /// ```
    func seek(to timestamp: TimeInterval) throws {
        // Prevent concurrent access with lock - crashes if seek and decode run simultaneously
        decoderLock.lock()
        defer { decoderLock.unlock() }

        guard isInitialized else {
            throw DecoderError.notInitialized
        }

        guard let formatCtx = formatContext else {
            throw DecoderError.notInitialized
        }

        // 1. Convert timestamp to stream time units
        // Time Base: Different time unit for each stream
        // - Example: 1/30000 (for 30fps video)
        // - PTS(Presentation Time Stamp) = actual time / time_base
        let timeBase = formatCtx.pointee.streams[videoStreamIndex]!.pointee.time_base
        let targetPTS = Int64(timestamp * Double(timeBase.den) / Double(timeBase.num))

        // 2. Seek to keyframe
        // av_seek_frame: Move to specified PTS
        // AVSEEK_FLAG_BACKWARD: Go to nearest keyframe before target time
        let seekResult = av_seek_frame(formatCtx, Int32(videoStreamIndex), targetPTS, AVSEEK_FLAG_BACKWARD)
        if seekResult < 0 {
            throw DecoderError.unknown("Seek failed")
        }

        // 3. Flush codec buffers
        // - When seeking, previously decoded data must be discarded
        // - Empty buffers and restart decoding from new position
        if let videoCtx = videoCodecContext, videoCtx.pointee.codec != nil {
            avcodec_flush_buffers(videoCtx)
        }
        if let audioCtx = audioCodecContext, audioCtx.pointee.codec != nil {
            avcodec_flush_buffers(audioCtx)
        }

        // 4. Reset frame number
        frameNumber = 0
    }

    /// @brief Returns the total playback duration of the video.
    ///
    /// @return Playback duration (seconds), nil if no information
    ///
    /// @details
    /// AV_NOPTS_VALUE:
    /// - Special value in FFmpeg indicating "no time information"
    /// - Some streaming files may not know their total length
    ///
    /// Usage example:
    /// ```swift
    /// if let duration = decoder.getDuration() {
    ///     print("Video length: \(duration) seconds")
    /// } else {
    ///     print("No duration information (live stream?)")
    /// }
    /// ```
    func getDuration() -> TimeInterval? {
        guard let formatCtx = formatContext else { return nil }

        let duration = formatCtx.pointee.duration

        // Check AV_NOPTS_VALUE (no time information)
        if duration == Int64(bitPattern: 0x8000000000000001) {
            return nil
        }

        // AV_TIME_BASE: FFmpeg's default time unit (1,000,000 = 1 second)
        // Divide duration by AV_TIME_BASE to convert to seconds
        return Double(duration) / Double(AV_TIME_BASE)
    }

    /// @brief Returns the timestamp of the current frame.
    ///
    /// @return Current timestamp (in seconds)
    ///
    /// @details
    /// Usage example:
    /// ```swift
    /// let currentTime = decoder.getCurrentTimestamp()
    /// print("Current playback position: \(currentTime) seconds")
    /// ```
    func getCurrentTimestamp() -> TimeInterval {
        return currentTimestamp
    }

    /// @brief Seeks to a specific frame number.
    ///
    /// @param targetFrame Frame number to seek to (starting from 0)
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: Not initialized
    ///   - `.unknown`: Seek failed
    ///
    /// @details
    /// Converts frame number to timestamp and seeks.
    /// - Frame number = Timestamp × Frame rate
    /// - Example: Frame 60 of 30fps video = 2 seconds
    ///
    /// Usage example:
    /// ```swift
    /// try decoder.seekToFrame(120)  // Move to frame 120
    /// ```
    func seekToFrame(_ targetFrame: Int) throws {
        guard isInitialized, let videoInfo = videoInfo else {
            throw DecoderError.notInitialized
        }

        // Convert frame number to timestamp
        let timestamp = Double(targetFrame) / videoInfo.frameRate
        try seek(to: timestamp)
    }

    /// @brief Moves to the next frame.
    ///
    /// @return Decoded video frame
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: Not initialized
    ///   - Other decoding-related errors
    ///
    /// @details
    /// Decodes next video frame from current position.
    /// Skips audio frames.
    ///
    /// Usage example:
    /// ```swift
    /// if let frame = try decoder.stepForward() {
    ///     print("Next frame: \(frame.timestamp) seconds")
    /// }
    /// ```
    func stepForward() throws -> VideoFrame? {
        // Continue decoding until video frame is found
        while let frames = try decodeNextFrame() {
            if let videoFrame = frames.video {
                return videoFrame
            }
            // Skip audio frames
        }
        return nil
    }

    /// @brief Moves to the previous frame.
    ///
    /// @throws DecoderError
    ///   - `.notInitialized`: Not initialized
    ///   - `.unknown`: Seek failed
    ///
    /// @details
    /// Move backward frame by frame:
    /// 1. Subtract one frame duration from current timestamp
    /// 2. Seek to that timestamp
    /// 3. Do not go below 0 seconds
    ///
    /// Notes:
    /// - Seeking operates on keyframe boundaries, so may not move to
    ///   exactly the previous frame
    /// - Use seekToFrame() for precise frame navigation
    ///
    /// Usage example:
    /// ```swift
    /// try decoder.stepBackward()
    /// if let frame = try decoder.stepForward() {
    ///     print("Previous frame: \(frame.timestamp) seconds")
    /// }
    /// ```
    func stepBackward() throws {
        guard isInitialized, let videoInfo = videoInfo else {
            throw DecoderError.notInitialized
        }

        // Calculate time duration of 1 frame
        let frameDuration = 1.0 / videoInfo.frameRate

        // Calculate timestamp of previous frame (don't go below 0 seconds)
        let previousTimestamp = max(0, currentTimestamp - frameDuration)

        // Seek to previous timestamp
        try seek(to: previousTimestamp)
    }

    // MARK: - Private Methods (Internal methods)
    // Helper methods used only within the class

    /// @brief Initializes the video stream.
    ///
    /// @param stream FFmpeg stream pointer
    ///
    /// @throws DecoderError (codec-related errors)
    ///
    /// @details
    /// Initialization steps:
    /// 1. Find codec (H.264, H.265, etc.)
    /// 2. Create codec context
    /// 3. Copy codec parameters
    /// 4. Open codec
    /// 5. Extract stream information
    private func initializeVideoStream(stream: UnsafeMutablePointer<AVStream>) throws {
        // 1. Get codec parameters
        guard let codecPar = stream.pointee.codecpar else {
            throw DecoderError.codecNotFound("video")
        }

        // 2. Find codec
        // avcodec_find_decoder: Find decoder by codec ID
        // - codec_id: Codec type (H.264 = AV_CODEC_ID_H264)
        guard let codec = avcodec_find_decoder(codecPar.pointee.codec_id) else {
            throw DecoderError.codecNotFound("video")
        }

        // 3. Allocate codec context
        // - Context: Struct containing state and settings needed for decoding
        guard let codecCtx = avcodec_alloc_context3(codec) else {
            throw DecoderError.cannotAllocateCodecContext
        }

        // 4. Copy parameters
        // - Copy codec parameters read from file to context
        // - Resolution, frame rate, pixel format, etc.
        if avcodec_parameters_to_context(codecCtx, codecPar) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)  // Free memory on failure
            throw DecoderError.cannotCopyCodecParameters
        }

        // 5. Open codec
        // - Initialize decoder to usable state
        if avcodec_open2(codecCtx, codec, nil) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotOpenCodec("video")
        }

        self.videoCodecContext = codecCtx

        // 6. Extract video information
        let width = Int(codecCtx.pointee.width)
        let height = Int(codecCtx.pointee.height)
        let timeBase = stream.pointee.time_base
        // av_q2d: Convert AVRational to double
        let frameRate = av_q2d(stream.pointee.r_frame_rate)

        self.videoInfo = VideoStreamInfo(
            width: width,
            height: height,
            frameRate: frameRate,
            codecName: String(cString: avcodec_get_name(codecPar.pointee.codec_id)),
            bitrate: Int(codecPar.pointee.bit_rate),
            timeBase: timeBase
        )
    }

    /// @brief Initializes the audio stream.
    ///
    /// @param stream FFmpeg stream pointer
    ///
    /// @throws DecoderError (codec-related errors)
    ///
    /// @details
    /// Similar to video stream initialization but extracts audio-related information.
    private func initializeAudioStream(stream: UnsafeMutablePointer<AVStream>) throws {
        guard let codecPar = stream.pointee.codecpar else {
            throw DecoderError.codecNotFound("audio")
        }

        // Find audio decoder (MP3, AAC, etc.)
        guard let codec = avcodec_find_decoder(codecPar.pointee.codec_id) else {
            throw DecoderError.codecNotFound("audio")
        }

        guard let codecCtx = avcodec_alloc_context3(codec) else {
            throw DecoderError.cannotAllocateCodecContext
        }

        if avcodec_parameters_to_context(codecCtx, codecPar) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotCopyCodecParameters
        }

        if avcodec_open2(codecCtx, codec, nil) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotOpenCodec("audio")
        }

        self.audioCodecContext = codecCtx

        // Extract audio information
        let sampleRate = Int(codecCtx.pointee.sample_rate)  // Sample rate: samples per second
        let channels = Int(codecCtx.pointee.ch_layout.nb_channels)  // Channels: mono=1, stereo=2
        let timeBase = stream.pointee.time_base

        self.audioInfo = AudioStreamInfo(
            sampleRate: sampleRate,
            channels: channels,
            codecName: String(cString: avcodec_get_name(codecPar.pointee.codec_id)),
            bitrate: Int(codecPar.pointee.bit_rate),
            timeBase: timeBase
        )
    }

    /// @brief Decodes compressed video packet.
    ///
    /// @param packet Compressed video packet
    ///
    /// @return Decoded VideoFrame, nil if EAGAIN
    ///
    /// @throws DecoderError
    ///
    /// @details
    /// Two-stage decoding:
    /// 1. Send: Send compressed packet to decoder
    /// 2. Receive: Receive decoded frame
    ///
    /// EAGAIN error:
    /// - Decoder needs more packets
    /// - Normal situation, continue sending next packet
    private func decodeVideoPacket(packet: UnsafeMutablePointer<AVPacket>) throws -> VideoFrame? {
        guard let codecCtx = videoCodecContext else {
            throw DecoderError.notInitialized
        }

        // Validate codec context before using it
        guard codecCtx.pointee.codec != nil else {
            throw DecoderError.notInitialized
        }

        // Validate packet before sending
        guard packet.pointee.size > 0, packet.pointee.data != nil else {
            // Empty or invalid packet, skip
            return nil
        }

        // 1. Send packet to decoder
        let sendResult = avcodec_send_packet(codecCtx, packet)
        if sendResult < 0 {
            throw DecoderError.sendPacketError(sendResult)
        }

        // 2. Allocate frame memory
        guard let frame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var framePtr: UnsafeMutablePointer<AVFrame>? = frame
        defer { av_frame_free(&framePtr) }

        // 3. Receive decoded frame
        let receiveResult = avcodec_receive_frame(codecCtx, frame)

        // Handle EAGAIN: Need more packets
        // -541478725: AVERROR_EOF
        // -11: AVERROR(EAGAIN) on Linux
        // -35: AVERROR(EAGAIN) on macOS
        if receiveResult == -541478725 || receiveResult == -11 || receiveResult == -35 {
            return nil  // Need next packet
        } else if receiveResult < 0 {
            throw DecoderError.receiveFrameError(receiveResult)
        }

        // 4. Convert frame to RGB format
        guard let videoFrame = try convertFrameToRGB(frame: frame) else {
            return nil
        }

        frameNumber += 1
        return videoFrame
    }

    /// @brief Decodes compressed audio packet.
    ///
    /// @param packet Compressed audio packet
    ///
    /// @return Decoded AudioFrame, nil if EAGAIN
    ///
    /// @throws DecoderError
    ///
    /// @details
    /// Same two-stage process as video decoding:
    /// 1. Send packet
    /// 2. Receive frame
    private func decodeAudioPacket(packet: UnsafeMutablePointer<AVPacket>) throws -> AudioFrame? {
        guard let codecCtx = audioCodecContext else {
            throw DecoderError.notInitialized
        }

        let sendResult = avcodec_send_packet(codecCtx, packet)
        if sendResult < 0 {
            throw DecoderError.sendPacketError(sendResult)
        }

        guard let frame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var framePtr: UnsafeMutablePointer<AVFrame>? = frame
        defer { av_frame_free(&framePtr) }

        let receiveResult = avcodec_receive_frame(codecCtx, frame)
        if receiveResult == -541478725 || receiveResult == -11 || receiveResult == -35 {
            return nil
        } else if receiveResult < 0 {
            throw DecoderError.receiveFrameError(receiveResult)
        }

        return convertFrameToAudio(frame: frame)
    }

    /// @brief Converts FFmpeg frame to RGB format.
    ///
    /// @param frame FFmpeg source frame
    ///
    /// @return Converted VideoFrame
    ///
    /// @throws DecoderError
    ///
    /// @details
    /// Conversion process:
    /// 1. Initialize scaler (once only)
    /// 2. Allocate RGB frame memory
    /// 3. Convert pixel format (YUV → RGB)
    /// 4. Copy to Swift Data object
    ///
    /// What is YUV?
    /// - Color space optimized for video compression
    /// - Y: Brightness, U/V: Color information
    /// - Less data than RGB
    ///
    /// BGRA vs RGB:
    /// - Metal (GPU) prefers BGRA format
    /// - B: Blue, G: Green, R: Red, A: Alpha (transparency)
    private func convertFrameToRGB(frame: UnsafeMutablePointer<AVFrame>) throws -> VideoFrame? {
        guard let codecCtx = videoCodecContext, let videoInfo = videoInfo else {
            throw DecoderError.notInitialized
        }

        let width = Int(frame.pointee.width)
        let height = Int(frame.pointee.height)

        // 1. Initialize scaler (once only)
        if scalerContext == nil {
            // sws_getContext: Create pixel format converter
            // Source: YUV format
            // Target: BGRA format (Metal compatible)
            // SWS_BILINEAR: High-quality interpolation algorithm
            scalerContext = sws_getContext(
                Int32(width),                    // Source width
                Int32(height),                   // Source height
                codecCtx.pointee.pix_fmt,       // Source pixel format
                Int32(width),                    // Target width
                Int32(height),                   // Target height
                AV_PIX_FMT_BGRA,                // Target pixel format
                Int32(SWS_BILINEAR.rawValue),   // Conversion algorithm
                nil, nil, nil
            )
        }

        guard let swsCtx = scalerContext else {
            throw DecoderError.scalerInitError
        }

        // 2. Allocate RGB frame memory
        guard let rgbFrame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var rgbFramePtr: UnsafeMutablePointer<AVFrame>? = rgbFrame
        defer { av_frame_free(&rgbFramePtr) }

        rgbFrame.pointee.format = AV_PIX_FMT_BGRA.rawValue
        rgbFrame.pointee.width = Int32(width)
        rgbFrame.pointee.height = Int32(height)

        // av_frame_get_buffer: Allocate frame data buffer
        // 32: Memory alignment (performance optimization)
        if av_frame_get_buffer(rgbFrame, 32) < 0 {
            throw DecoderError.cannotAllocateFrame
        }

        // 3. Convert pixel format
        // sws_scale: Actual pixel data conversion
        // withUnsafePointer: Safe pointer access
        _ = withUnsafePointer(to: &frame.pointee.data) { srcDataPtr in
            withUnsafePointer(to: &frame.pointee.linesize) { srcLinesizePtr in
                withUnsafePointer(to: &rgbFrame.pointee.data) { dstDataPtr in
                    withUnsafePointer(to: &rgbFrame.pointee.linesize) { dstLinesizePtr in
                        sws_scale(
                            swsCtx,
                            UnsafeRawPointer(srcDataPtr).assumingMemoryBound(to: UnsafePointer<UInt8>?.self),
                            UnsafeRawPointer(srcLinesizePtr).assumingMemoryBound(to: Int32.self),
                            0,
                            Int32(height),
                            UnsafeMutableRawPointer(mutating: dstDataPtr).assumingMemoryBound(to: UnsafeMutablePointer<UInt8>?.self),
                            UnsafeMutableRawPointer(mutating: dstLinesizePtr).assumingMemoryBound(to: Int32.self)
                        )
                    }
                }
            }
        }

        // 4. Copy RGB data to Swift Data
        // linesize: Bytes per line (width × bytes per pixel)
        let lineSize = Int(rgbFrame.pointee.linesize.0)
        let dataSize = lineSize * height
        let data = Data(bytes: rgbFrame.pointee.data.0!, count: dataSize)

        // 5. Calculate timestamp
        // PTS (Presentation Time Stamp): Time to display frame
        let pts = frame.pointee.pts
        let timeBase = videoInfo.timeBase
        let timestamp = Double(pts) * Double(timeBase.num) / Double(timeBase.den)

        // Update currentTimestamp (used for synchronization)
        self.currentTimestamp = timestamp

        // 6. Check keyframe
        // AV_FRAME_FLAG_KEY: Whether this frame is a keyframe
        let isKeyFrame = (frame.pointee.flags & Int32(AV_FRAME_FLAG_KEY)) != 0

        return VideoFrame(
            timestamp: timestamp,
            width: width,
            height: height,
            pixelFormat: .rgba,
            data: data,
            lineSize: lineSize,
            frameNumber: frameNumber,
            isKeyFrame: isKeyFrame
        )
    }

    /// @brief Converts FFmpeg audio frame to AudioFrame.
    ///
    /// @param frame FFmpeg audio frame
    ///
    /// @return Converted AudioFrame
    ///
    /// @details
    /// Audio format types:
    /// - Planar: Samples of each channel are separated (L L L... R R R...)
    /// - Interleaved: Channels are mixed (L R L R L R...)
    private func convertFrameToAudio(frame: UnsafeMutablePointer<AVFrame>) -> AudioFrame? {
        guard let audioInfo = audioInfo else {
            return nil
        }

        let sampleCount = Int(frame.pointee.nb_samples)  // Number of samples
        let channels = Int(frame.pointee.ch_layout.nb_channels)  // Number of channels

        // 1. Determine audio format
        let format: AudioFormat
        switch frame.pointee.format {
        case AV_SAMPLE_FMT_FLTP.rawValue:
            format = .floatPlanar  // 32-bit float, planar
        case AV_SAMPLE_FMT_FLT.rawValue:
            format = .floatInterleaved  // 32-bit float, interleaved
        case AV_SAMPLE_FMT_S16P.rawValue:
            format = .s16Planar  // 16-bit integer, planar
        case AV_SAMPLE_FMT_S16.rawValue:
            format = .s16Interleaved  // 16-bit integer, interleaved
        default:
            return nil  // Unsupported format
        }

        // 2. Calculate data size
        let bytesPerSample = format.bytesPerSample
        let dataSize = sampleCount * channels * bytesPerSample
        var data = Data(count: dataSize)

        // 3. Copy data according to format
        if format.isInterleaved {
            // Interleaved: Copy at once
            data.withUnsafeMutableBytes { (destBytes: UnsafeMutableRawBufferPointer) in
                if let destPtr = destBytes.baseAddress {
                    memcpy(destPtr, frame.pointee.data.0, dataSize)
                }
            }
        } else {
            // Planar: Copy each channel separately
            let bytesPerChannel = sampleCount * bytesPerSample
            let dataPointers = [frame.pointee.data.0, frame.pointee.data.1, frame.pointee.data.2, frame.pointee.data.3,
                                frame.pointee.data.4, frame.pointee.data.5, frame.pointee.data.6, frame.pointee.data.7]
            data.withUnsafeMutableBytes { (destBytes: UnsafeMutableRawBufferPointer) in
                if let destPtr = destBytes.baseAddress {
                    for ch in 0..<channels {
                        if let srcPtr = dataPointers[ch] {
                            let offset = ch * bytesPerChannel
                            memcpy(destPtr + offset, srcPtr, bytesPerChannel)
                        }
                    }
                }
            }
        }

        // 4. Calculate timestamp
        let pts = frame.pointee.pts
        let timeBase = audioInfo.timeBase
        let timestamp = Double(pts) * Double(timeBase.num) / Double(timeBase.den)

        return AudioFrame(
            timestamp: timestamp,
            sampleRate: audioInfo.sampleRate,
            channels: channels,
            format: format,
            data: data,
            sampleCount: sampleCount
        )
    }

    /// @brief Cleans up all FFmpeg resources.
    ///
    /// @details
    /// Preventing memory leaks:
    /// - C libraries have no automatic memory management
    /// - All used resources must be manually freed
    /// - Cleanup order: Scaler → Codec contexts → Format context
    ///
    /// Notes:
    /// - Set pointers to nil to prevent double-free
    /// - Automatically called in deinit
    private func cleanup() {
        // 1. Clean up scaler
        if let swsCtx = scalerContext {
            sws_freeContext(swsCtx)
            scalerContext = nil
        }

        // 2. Clean up video codec context
        if videoCodecContext != nil {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = videoCodecContext
            avcodec_free_context(&ctx)
            videoCodecContext = nil
        }

        // 3. Clean up audio codec context
        if audioCodecContext != nil {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = audioCodecContext
            avcodec_free_context(&ctx)
            audioCodecContext = nil
        }

        // 4. Clean up format context
        if formatContext != nil {
            var ctx: UnsafeMutablePointer<AVFormatContext>? = formatContext
            avformat_close_input(&ctx)
            formatContext = nil
        }

        // 5. Reset state
        isInitialized = false
    }
}

// MARK: - Supporting Types

/// @struct VideoStreamInfo
/// @brief Struct containing detailed information of video stream
///
/// @details
/// Property descriptions:
/// - width/height: Video width/height in pixels (e.g., 1920×1080)
/// - frameRate: Frames per second (e.g., 30fps, 60fps)
/// - codecName: Codec name (e.g., "h264", "hevc")
/// - bitrate: Bits per second, quality indicator (higher = better quality)
/// - timeBase: Time unit (fractional form: 1/30000)
struct VideoStreamInfo {
    /// @var width
    /// @brief Video width in pixels
    let width: Int

    /// @var height
    /// @brief Video height in pixels
    let height: Int

    /// @var frameRate
    /// @brief Frames per second
    let frameRate: Double

    /// @var codecName
    /// @brief Codec name
    let codecName: String

    /// @var bitrate
    /// @brief Bits per second
    let bitrate: Int

    /// @var timeBase
    /// @brief Time unit
    let timeBase: AVRational
}

/// @struct AudioStreamInfo
/// @brief Struct containing detailed information of audio stream
///
/// @details
/// Property descriptions:
/// - sampleRate: Sample rate, audio quality indicator (44100Hz = CD quality)
/// - channels: Number of channels (1=mono, 2=stereo, 6=5.1 surround)
/// - codecName: Codec name (e.g., "mp3", "aac")
/// - bitrate: Bits per second
/// - timeBase: Time unit
struct AudioStreamInfo {
    /// @var sampleRate
    /// @brief Sample rate (samples per second)
    let sampleRate: Int

    /// @var channels
    /// @brief Number of channels
    let channels: Int

    /// @var codecName
    /// @brief Codec name
    let codecName: String

    /// @var bitrate
    /// @brief Bits per second
    let bitrate: Int

    /// @var timeBase
    /// @brief Time unit
    let timeBase: AVRational
}
