/// @file DecoderError.swift
/// @brief Error types for video/audio decoder
/// @author BlackboxPlayer Development Team
/// @details
/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                    DecoderError - Video/Audio Decoder Error Types            ║
 ║                                                                              ║
 ║  Purpose:                                                                    ║
 ║    Defines all possible errors from FFmpeg-based video/audio decoders.      ║
 ║    Provides clear error types for easier problem diagnosis and resolution.  ║
 ║                                                                              ║
 ║  Core Features:                                                              ║
 ║    • 18 specific error cases defined                                         ║
 ║    • Associated Values for additional information                            ║
 ║    • LocalizedError for user-friendly messages                               ║
 ║    • Converts FFmpeg error codes to Swift Errors                             ║
 ║                                                                              ║
 ║  Error Categories:                                                           ║
 ║    1. File-related (cannotOpenFile, cannotFindStreamInfo)                    ║
 ║    2. Stream-related (noVideoStream, noAudioStream)                          ║
 ║    3. Codec-related (codecNotFound, cannotOpenCodec)                         ║
 ║    4. Memory allocation (cannotAllocateFrame, cannotAllocatePacket)          ║
 ║    5. Decoding process (readFrameError, sendPacketError, receiveFrameError)  ║
 ║    6. Scaling (scalerInitError, scaleFrameError)                             ║
 ║    7. State-related (alreadyInitialized, notInitialized, endOfFile)          ║
 ║                                                                              ║
 ║  Usage Example:                                                              ║
 ║    ```swift                                                                  ║
 ║    // Throwing errors                                                        ║
 ║    throw DecoderError.cannotOpenFile(filePath)                               ║
 ║                                                                              ║
 ║    // Error handling                                                         ║
 ║    do {                                                                      ║
 ║        try decoder.initialize()                                              ║
 ║    } catch DecoderError.codecNotFound(let name) {                            ║
 ║        print("Missing codec: \(name)")                                       ║
 ║    } catch DecoderError.cannotOpenFile(let path) {                           ║
 ║        print("File error: \(path)")                                          ║
 ║    } catch {                                                                 ║
 ║        print("Other error: \(error.localizedDescription)")                   ║
 ║    }                                                                         ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ What is the Swift Error Protocol?                                           │
 └──────────────────────────────────────────────────────────────────────────────┘

 Error is the core protocol of Swift's error handling system.

 ┌───────────────────────────────────────────────────────────────────────────┐
 │ Features of the Error Protocol                                           │
 ├───────────────────────────────────────────────────────────────────────────┤
 │                                                                           │
 │ 1. No Protocol Requirements                                              │
 │    - protocol Error {} (empty)                                           │
 │    - Serves only as a type marker                                        │
 │                                                                           │
 │ 2. Integrated with throw/catch System                                    │
 │    - throw to throw errors                                               │
 │    - do-catch to catch errors                                            │
 │    - try to propagate errors                                             │
 │                                                                           │
 │ 3. Type Safety                                                            │
 │    - Error type checking at compile time                                 │
 │    - Warnings for missing error handling                                 │
 │                                                                           │
 │ 4. Associated Values Support                                             │
 │    - Can attach data to enum cases                                       │
 │    - Pass context information when errors occur                          │
 │                                                                           │
 └───────────────────────────────────────────────────────────────────────────┘


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ What are Associated Values?                                                 │
 └──────────────────────────────────────────────────────────────────────────────┘

 A feature that allows attaching additional data to each case of an enum.

 Basic enum (without Associated Values):
 ```swift
 enum TrafficLight {
 case red
 case yellow
 case green
 }
 let light = TrafficLight.red  // No additional information
 ```

 Enum with Associated Values:
 ```swift
 enum DecoderError: Error {
 case cannotOpenFile(String)  // Stores file path
 case readFrameError(Int32)   // Stores error code
 }

 // Usage
 let error1 = DecoderError.cannotOpenFile("/path/to/video.mp4")
 let error2 = DecoderError.readFrameError(-11)  // AVERROR(EAGAIN)

 // Extracting values
 switch error1 {
 case .cannotOpenFile(let path):
 print("Failed to open: \(path)")  // "Failed to open: /path/to/video.mp4"
 case .readFrameError(let code):
 print("Error code: \(code)")
 default:
 break
 }
 ```

 Advantages:
 1. Passes context information when errors occur
 2. Facilitates debugging
 3. Provides specific error messages to users
 4. Maintains type safety


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ FFmpeg Decoding Process Overview                                            │
 └──────────────────────────────────────────────────────────────────────────────┘

 FFmpeg goes through the following steps to decode video/audio:

 ┌────────────────────────────────────────────────────────────────────────┐
 │                         FFmpeg Decoding Pipeline                       │
 ├────────────────────────────────────────────────────────────────────────┤
 │                                                                        │
 │  1. Open File                                                          │
 │     └─ avformat_open_input()                                           │
 │     └─ Error: cannotOpenFile                                           │
 │                                                                        │
 │  2. Find Stream Info                                                   │
 │     └─ avformat_find_stream_info()                                     │
 │     └─ Error: cannotFindStreamInfo                                     │
 │                                                                        │
 │  3. Select Video/Audio Stream                                          │
 │     └─ av_find_best_stream()                                           │
 │     └─ Error: noVideoStream, noAudioStream                             │
 │                                                                        │
 │  4. Find Codec                                                         │
 │     └─ avcodec_find_decoder()                                          │
 │     └─ Error: codecNotFound                                            │
 │                                                                        │
 │  5. Allocate Codec Context                                             │
 │     └─ avcodec_alloc_context3()                                        │
 │     └─ Error: cannotAllocateCodecContext                               │
 │                                                                        │
 │  6. Copy Codec Parameters                                              │
 │     └─ avcodec_parameters_to_context()                                 │
 │     └─ Error: cannotCopyCodecParameters                                │
 │                                                                        │
 │  7. Open Codec                                                         │
 │     └─ avcodec_open2()                                                 │
 │     └─ Error: cannotOpenCodec                                          │
 │                                                                        │
 │  8. Allocate Frame/Packet                                              │
 │     └─ av_frame_alloc(), av_packet_alloc()                             │
 │     └─ Error: cannotAllocateFrame, cannotAllocatePacket                │
 │                                                                        │
 │  [Decoding Loop Starts]                                                │
 │                                                                        │
 │  9. Read Packet                                                        │
 │     └─ av_read_frame()                                                 │
 │     └─ Error: readFrameError, endOfFile                                │
 │                                                                        │
 │  10. Send Packet to Decoder                                            │
 │      └─ avcodec_send_packet()                                          │
 │      └─ Error: sendPacketError                                         │
 │                                                                        │
 │  11. Receive Frame from Decoder                                        │
 │      └─ avcodec_receive_frame()                                        │
 │      └─ Error: receiveFrameError                                       │
 │                                                                        │
 │  12. Frame Scaling/Conversion                                          │
 │      └─ sws_scale() (video), swr_convert() (audio)                     │
 │      └─ Error: scalerInitError, scaleFrameError                        │
 │                                                                        │
 │  [Repeat 9-12]                                                         │
 │                                                                        │
 └────────────────────────────────────────────────────────────────────────┘


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ AVERROR Code Explanation                                                    │
 └──────────────────────────────────────────────────────────────────────────────┘

 FFmpeg uses negative error codes. Key codes:

 • AVERROR_EOF = -541478725 (end of file)
 • AVERROR(EAGAIN) = -11 (retry needed)
 • AVERROR(EINVAL) = -22 (invalid argument)
 • AVERROR(ENOMEM) = -12 (out of memory)
 • AVERROR_DECODER_NOT_FOUND = -1094995529 (decoder not found)

 Usage example:
 ```swift
 let ret = av_read_frame(formatContext, packet)
 if ret < 0 {
 if ret == AVERROR_EOF {
 throw DecoderError.endOfFile
 } else {
 throw DecoderError.readFrameError(ret)
 }
 }
 ```
 */

import Foundation

// MARK: - DecoderError Enumeration

/// @enum DecoderError
/// @brief Errors that can occur during video/audio decoding
///
/// Type-safe representation of all error conditions in FFmpeg-based decoders.
///
/// - Note: Error Protocol
///   Adopts the Error protocol to integrate with Swift's error handling system.
///   Can be used with throw, do-catch, and try keywords.
///
/// - Important: Associated Values
///   Each case can contain additional information:
///   - String: File path, codec name, general message
///   - Int32: FFmpeg error code
///   - Int: Stream index
///
/// - SeeAlso: `VideoDecoder`, `AudioPlayer`
enum DecoderError: Error {

    // MARK: File-related Errors

    /// @brief Cannot open input file
    ///
    /// FFmpeg function: avformat_open_input()
    ///
    /// When it occurs:
    /// - File does not exist
    /// - No file permissions
    /// - File locked by another process
    /// - Unsupported file format
    ///
    /// Associated Value:
    /// - String: Failed file path
    ///
    /// Resolution:
    /// 1. Check file existence: FileManager.default.fileExists(atPath:)
    /// 2. Check read permission: FileManager.default.isReadableFile(atPath:)
    /// 3. Check file extension: .mp4, .avi, .mov, etc.
    /// 4. Check file corruption: Test playback with another player
    ///
    /// Usage example:
    /// ```swift
    /// guard FileManager.default.fileExists(atPath: filePath) else {
    ///     throw DecoderError.cannotOpenFile(filePath)
    /// }
    /// ```
    case cannotOpenFile(String)

    /// @brief Cannot find stream information
    ///
    /// FFmpeg function: avformat_find_stream_info()
    ///
    /// When it occurs:
    /// - Corrupted file header
    /// - Invalid file format
    /// - File not fully downloaded
    /// - Encrypted file
    ///
    /// Associated Value:
    /// - String: Failed file path
    ///
    /// Resolution:
    /// 1. Check file integrity
    /// 2. Check file size (not 0 bytes)
    /// 3. Re-download file
    /// 4. Check if playable with another player
    ///
    /// Technical explanation:
    /// - avformat_find_stream_info reads part of file to gather codec information
    /// - Usually analyzes first few frames of file
    /// - Corrupted headers are detected at this stage
    case cannotFindStreamInfo(String)

    // MARK: Stream-related Errors

    /// @brief No video stream in file
    ///
    /// FFmpeg function: av_find_best_stream(AVMEDIA_TYPE_VIDEO)
    ///
    /// When it occurs:
    /// - Audio-only file (music files, etc.)
    /// - Video stream is corrupted
    /// - Unsupported video format
    ///
    /// Resolution:
    /// 1. Check if file actually contains video
    /// 2. Check stream information with ffprobe:
    ///    `ffprobe -show_streams video.mp4`
    /// 3. Use AudioPlayer if audio-only file
    ///
    /// Note:
    /// - Dashcam files should always have video stream
    /// - This error likely indicates file corruption
    case noVideoStream

    /// @brief No audio stream in file
    ///
    /// FFmpeg function: av_find_best_stream(AVMEDIA_TYPE_AUDIO)
    ///
    /// When it occurs:
    /// - Video-only file (silent video)
    /// - Audio stream is corrupted
    /// - File encoded without audio
    ///
    /// Resolution:
    /// 1. This error may be normal for some dashcams
    /// 2. Play video without audio
    /// 3. Notify user "No audio"
    ///
    /// Note:
    /// - Some dashcams provide audio recording off feature
    /// - In this case, this error is a normal situation
    case noAudioStream

    // MARK: Codec-related Errors

    /// @brief Cannot find codec for stream
    ///
    /// FFmpeg function: avcodec_find_decoder()
    ///
    /// When it occurs:
    /// - Unsupported codec (e.g., HEVC in old FFmpeg)
    /// - Codec excluded from FFmpeg build
    /// - Corrupted codec ID
    ///
    /// Associated Value:
    /// - String: Codec name or ID
    ///
    /// Resolution:
    /// 1. Check FFmpeg build: whether required codec is included
    /// 2. Check codecs supported by dashcam:
    ///    - Common: H.264 (AVC), H.265 (HEVC)
    ///    - Audio: AAC, MP3, PCM
    /// 3. Re-encode with different codec
    ///
    /// Technical explanation:
    /// ```
    /// Codec ID → avcodec_find_decoder() → Decoder struct
    ///           ↓ Failure
    ///           codecNotFound error
    /// ```
    case codecNotFound(String)

    /// @brief Codec context allocation failure
    ///
    /// FFmpeg function: avcodec_alloc_context3()
    ///
    /// When it occurs:
    /// - Out of memory
    /// - System resources exhausted
    ///
    /// Resolution:
    /// 1. Check available memory
    /// 2. Close other applications
    /// 3. Restart system
    ///
    /// Memory calculation:
    /// - 1920x1080 frame: ~8MB
    /// - Decoder context: ~1MB
    /// - Multi-channel (5): ~45MB
    case cannotAllocateCodecContext

    /// @brief Codec parameters copy failure
    ///
    /// FFmpeg function: avcodec_parameters_to_context()
    ///
    /// When it occurs:
    /// - Invalid parameters
    /// - Codec context is null
    /// - Out of memory
    ///
    /// Resolution:
    /// - Usually indicates code bug
    /// - Possible file corruption
    /// - Test with different file
    case cannotCopyCodecParameters

    /// @brief Cannot open codec
    ///
    /// FFmpeg function: avcodec_open2()
    ///
    /// When it occurs:
    /// - Invalid codec options
    /// - Hardware acceleration failure
    /// - Codec initialization failure
    ///
    /// Associated Value:
    /// - String: Codec name
    ///
    /// Resolution:
    /// 1. Disable hardware acceleration
    /// 2. Switch to software decoder
    /// 3. Check codec options
    ///
    /// Example:
    /// ```swift
    /// // Try hardware acceleration
    /// if avcodec_open2(context, codec, &hwOptions) < 0 {
    ///     // Retry with software if failed
    ///     if avcodec_open2(context, codec, nil) < 0 {
    ///         throw DecoderError.cannotOpenCodec(codecName)
    ///     }
    /// }
    /// ```
    case cannotOpenCodec(String)

    // MARK: Memory Allocation Errors

    /// @brief Frame structure allocation failure
    ///
    /// FFmpeg function: av_frame_alloc()
    ///
    /// When it occurs:
    /// - Out of memory
    /// - System resources exhausted
    ///
    /// Resolution:
    /// - Free memory
    /// - Close other applications
    /// - Reduce buffer size
    ///
    /// Memory requirements:
    /// - AVFrame struct: ~256 bytes
    /// - Actual frame data allocated separately
    case cannotAllocateFrame

    /// @brief Packet structure allocation failure
    ///
    /// FFmpeg function: av_packet_alloc()
    ///
    /// When it occurs:
    /// - Out of memory
    ///
    /// Resolution:
    /// - Free memory
    ///
    /// Memory requirements:
    /// - AVPacket struct: ~88 bytes
    /// - Compressed data stored separately
    case cannotAllocatePacket

    // MARK: Decoding Process Errors

    /// @brief Read frame from file failure
    ///
    /// FFmpeg function: av_read_frame()
    ///
    /// When it occurs:
    /// - File corruption
    /// - End of file reached (AVERROR_EOF)
    /// - I/O error
    /// - Disk read failure
    ///
    /// Associated Value:
    /// - Int32: FFmpeg error code
    ///   - AVERROR_EOF (-541478725): End of file
    ///   - AVERROR(EIO) (-5): I/O error
    ///
    /// Resolution:
    /// ```swift
    /// let ret = av_read_frame(formatContext, packet)
    /// if ret < 0 {
    ///     if ret == AVERROR_EOF {
    ///         throw DecoderError.endOfFile
    ///     } else {
    ///         throw DecoderError.readFrameError(ret)
    ///     }
    /// }
    /// ```
    case readFrameError(Int32)

    /// @brief Send packet to decoder failure
    ///
    /// FFmpeg function: avcodec_send_packet()
    ///
    /// When it occurs:
    /// - Decoder is full (AVERROR(EAGAIN))
    /// - Invalid packet data
    /// - Decoder internal error
    ///
    /// Associated Value:
    /// - Int32: FFmpeg error code
    ///   - AVERROR(EAGAIN) (-11): Buffer full, need to receive frame first
    ///
    /// Resolution:
    /// ```swift
    /// let ret = avcodec_send_packet(context, packet)
    /// if ret == AVERROR(EAGAIN) {
    ///     // Call avcodec_receive_frame() first
    ///     // Then retry send_packet
    /// } else if ret < 0 {
    ///     throw DecoderError.sendPacketError(ret)
    /// }
    /// ```
    case sendPacketError(Int32)

    /// @brief Receive frame from decoder failure
    ///
    /// FFmpeg function: avcodec_receive_frame()
    ///
    /// When it occurs:
    /// - Frame not ready yet (AVERROR(EAGAIN))
    /// - Decoding error
    /// - Out of memory
    ///
    /// Associated Value:
    /// - Int32: FFmpeg error code
    ///   - AVERROR(EAGAIN) (-11): Need more packets
    ///   - AVERROR_EOF: Decoder flush complete
    ///
    /// Resolution:
    /// ```swift
    /// let ret = avcodec_receive_frame(context, frame)
    /// if ret == AVERROR(EAGAIN) {
    ///     // Supply more data via avcodec_send_packet()
    ///     continue
    /// } else if ret == AVERROR_EOF {
    ///     // Decoding complete
    ///     break
    /// } else if ret < 0 {
    ///     throw DecoderError.receiveFrameError(ret)
    /// }
    /// ```
    ///
    /// Decoding loop pattern:
    /// ```
    /// while hasMorePackets {
    ///     send_packet(packet)  ← Input compressed data
    ///     while true {
    ///         receive_frame(frame)  ← Output decompressed frame
    ///         if EAGAIN { break }  ← Need more packets
    ///         // Process frame
    ///     }
    /// }
    /// ```
    case receiveFrameError(Int32)

    // MARK: Scaling/Conversion Errors

    /// @brief Scaler/resampler initialization failure
    ///
    /// FFmpeg functions:
    /// - sws_getContext() (video scaler)
    /// - swr_alloc_set_opts() (audio resampler)
    ///
    /// When it occurs:
    /// - Unsupported pixel format conversion
    /// - Invalid resolution (0 or negative)
    /// - Out of memory
    ///
    /// Resolution:
    /// 1. Check source/destination formats
    /// 2. Validate resolution
    /// 3. Free memory
    ///
    /// Video scaler example:
    /// ```swift
    /// // YUV420p → RGB conversion
    /// let swsContext = sws_getContext(
    ///     width, height, AV_PIX_FMT_YUV420P,  // Source
    ///     width, height, AV_PIX_FMT_RGB24,    // Destination
    ///     SWS_BILINEAR, nil, nil, nil
    /// )
    /// guard swsContext != nil else {
    ///     throw DecoderError.scalerInitError
    /// }
    /// ```
    case scalerInitError

    /// @brief Frame scaling/conversion failure
    ///
    /// FFmpeg functions:
    /// - sws_scale() (video)
    /// - swr_convert() (audio)
    ///
    /// When it occurs:
    /// - Insufficient buffer size
    /// - Scaler not initialized
    /// - Memory error
    ///
    /// Resolution:
    /// 1. Check output buffer size
    /// 2. Verify scaler initialization
    /// 3. Validate input frame
    ///
    /// Usage example:
    /// ```swift
    /// let height = sws_scale(
    ///     swsContext,
    ///     frame.data, frame.linesize, 0, frame.height,
    ///     rgbFrame.data, rgbFrame.linesize
    /// )
    /// guard height == frame.height else {
    ///     throw DecoderError.scaleFrameError
    /// }
    /// ```
    case scaleFrameError

    // MARK: State-related Errors

    /// @brief Invalid stream index
    ///
    /// When it occurs:
    /// - Negative index
    /// - Index exceeds file's stream count
    /// - Stream type mismatch (accessing audio with video index, etc.)
    ///
    /// Associated Value:
    /// - Int: Invalid index value
    ///
    /// Resolution:
    /// ```swift
    /// guard streamIndex >= 0 && streamIndex < formatContext.nb_streams else {
    ///     throw DecoderError.invalidStreamIndex(streamIndex)
    /// }
    /// ```
    case invalidStreamIndex(Int)

    /// @brief Decoder already initialized
    ///
    /// When it occurs:
    /// - Calling initialize() twice
    /// - Attempting to reopen already opened decoder
    ///
    /// Resolution:
    /// ```swift
    /// guard !isInitialized else {
    ///     throw DecoderError.alreadyInitialized
    /// }
    /// isInitialized = true
    /// // Initialization logic...
    /// ```
    case alreadyInitialized

    /// @brief Decoder not initialized
    ///
    /// When it occurs:
    /// - Calling other methods before initialize()
    /// - Continuing to use after initialization failure
    ///
    /// Resolution:
    /// ```swift
    /// func decodeNextFrame() throws -> Frame? {
    ///     guard isInitialized else {
    ///         throw DecoderError.notInitialized
    ///     }
    ///     // Decoding logic...
    /// }
    /// ```
    case notInitialized

    /// @brief End of file reached
    ///
    /// FFmpeg error: AVERROR_EOF
    ///
    /// When it occurs:
    /// - av_read_frame() has no more data to read
    /// - Normal end of file
    ///
    /// Resolution:
    /// - Not an error but a normal termination signal
    /// - Need to flush decoder (output remaining frames)
    ///
    /// Decoder flush:
    /// ```swift
    /// // When EOF reached
    /// avcodec_send_packet(context, nil)  // nil = flush signal
    /// while true {
    ///     let ret = avcodec_receive_frame(context, frame)
    ///     if ret == AVERROR_EOF { break }  // All frames output
    ///     // Process frame
    /// }
    /// ```
    case endOfFile

    /// @brief Unknown error
    ///
    /// When it occurs:
    /// - Error not belonging to above categories
    /// - FFmpeg internal error
    /// - Unexpected situation
    ///
    /// Associated Value:
    /// - String: Error description message
    ///
    /// Resolution:
    /// - Check logs
    /// - Check FFmpeg version
    /// - Submit bug report
    case unknown(String)
}

// MARK: - LocalizedError Extension

/*
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ LocalizedError Protocol                                                      │
 └──────────────────────────────────────────────────────────────────────────────┘

 LocalizedError is a protocol that provides error messages to display to users.

 Protocol definition:
 ```swift
 protocol LocalizedError : Error {
 var errorDescription: String? { get }
 var failureReason: String? { get }
 var recoverySuggestion: String? { get }
 var helpAnchor: String? { get }
 }
 ```

 We only implement errorDescription:
 - errorDescription: Error message to display to user

 Usage example:
 ```swift
 do {
 try decoder.initialize()
 } catch {
 // error.localizedDescription automatically uses errorDescription
 print(error.localizedDescription)
 // Output: "Cannot open file: /path/to/video.mp4"
 }
 ```

 Advantages:
 1. Consistent error messages
 2. Localization support (future)
 3. Easy to use in UI
 */

/// @extension DecoderError
/// @brief LocalizedError implementation
///
/// Provides user-friendly messages for each DecoderError case.
///
/// - Note: errorDescription
///   Returns String? type but always returns String (never nil).
///   This is Optional due to protocol requirement.
///
/// - Important: Message writing guide
///   1. Clear and specific
///   2. Minimize technical terms (for users)
///   3. Include Associated Value information
///   4. Written in English (future localization)
extension DecoderError: LocalizedError {

    /// @var errorDescription
    /// @brief Error description string
    ///
    /// Returns human-readable description for each error case.
    ///
    /// - Returns: Error description string (always non-nil)
    ///
    /// Message format:
    /// - Action failure: "Cannot [action]: [details]"
    /// - Missing resource: "No [resource] found"
    /// - State error: "[Component] [state]"
    ///
    /// Usage example:
    /// ```swift
    /// let error = DecoderError.cannotOpenFile("/video.mp4")
    /// print(error.errorDescription ?? "Unknown error")
    /// // Output: "Cannot open file: /video.mp4"
    /// ```
    var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path):
            return "Cannot open file: \(path)"

        case .cannotFindStreamInfo(let path):
            return "Cannot find stream information: \(path)"

        case .noVideoStream:
            return "No video stream found"

        case .noAudioStream:
            return "No audio stream found"

        case .codecNotFound(let name):
            return "Codec not found: \(name)"

        case .cannotAllocateCodecContext:
            return "Cannot allocate codec context"

        case .cannotCopyCodecParameters:
            return "Cannot copy codec parameters"

        case .cannotOpenCodec(let name):
            return "Cannot open codec: \(name)"

        case .cannotAllocateFrame:
            return "Cannot allocate frame"

        case .cannotAllocatePacket:
            return "Cannot allocate packet"

        case .readFrameError(let code):
            // Including FFmpeg error code for easier debugging
            return "Read frame error: \(code)"

        case .sendPacketError(let code):
            return "Send packet error: \(code)"

        case .receiveFrameError(let code):
            return "Receive frame error: \(code)"

        case .scalerInitError:
            return "Scaler initialization error"

        case .scaleFrameError:
            return "Frame scaling error"

        case .invalidStreamIndex(let index):
            return "Invalid stream index: \(index)"

        case .alreadyInitialized:
            return "Decoder already initialized"

        case .notInitialized:
            return "Decoder not initialized"

        case .endOfFile:
            // This is not actually an error but a normal termination
            return "End of file reached"

        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                           Error Handling Patterns                            ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝

 1. Basic Pattern:
 ```swift
 func decodeVideo() throws {
 // Open file
 guard canOpen(file) else {
 throw DecoderError.cannotOpenFile(filePath)
 }

 // Find codec
 guard let codec = findCodec() else {
 throw DecoderError.codecNotFound("H.264")
 }

 // Decoding...
 }

 // Usage
 do {
 try decodeVideo()
 } catch DecoderError.cannotOpenFile(let path) {
 print("File error: \(path)")
 // Ask user to select file again
 } catch DecoderError.codecNotFound(let name) {
 print("Codec \(name) not supported")
 // Ask user for different file
 } catch {
 print("Unexpected error: \(error)")
 }
 ```

 2. Using Result Type:
 ```swift
 func decodeVideo() -> Result<VideoFrame, DecoderError> {
 do {
 let frame = try performDecode()
 return .success(frame)
 } catch let error as DecoderError {
 return .failure(error)
 } catch {
 return .failure(.unknown(error.localizedDescription))
 }
 }

 // Usage
 switch decodeVideo() {
 case .success(let frame):
 display(frame)
 case .failure(let error):
 handle(error)
 }
 ```

 3. Optional Conversion:
 ```swift
 let frame = try? decoder.decodeNextFrame()
 if frame == nil {
 // Error occurred (no details available)
 }
 ```

 4. Error Chaining:
 ```swift
 func loadAndDecode(_ path: String) throws -> VideoFrame {
 let data = try loadFile(path)  // Can throw FileError
 let frame = try decode(data)   // Can throw DecoderError
 return frame
 }

 // Handle both error types
 do {
 let frame = try loadAndDecode("/video.mp4")
 } catch let error as FileError {
 // Handle file error
 } catch let error as DecoderError {
 // Handle decoder error
 } catch {
 // Handle other errors
 }
 ```
 */
