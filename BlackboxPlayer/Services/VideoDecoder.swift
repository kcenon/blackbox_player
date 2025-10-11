//
//  VideoDecoder.swift
//  BlackboxPlayer
//
//  FFmpeg-based video/audio decoder
//

import Foundation
import CoreGraphics

/// Video decoder that wraps FFmpeg for decoding dashcam videos
class VideoDecoder {
    // MARK: - Properties

    /// Path to the video file
    private let filePath: String

    /// FFmpeg format context
    private var formatContext: UnsafeMutablePointer<AVFormatContext>?

    /// Video codec context
    private var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?

    /// Audio codec context
    private var audioCodecContext: UnsafeMutablePointer<AVCodecContext>?

    /// Scaler context for pixel format conversion
    private var scalerContext: UnsafeMutablePointer<SwsContext>?

    /// Video stream index
    private var videoStreamIndex: Int = -1

    /// Audio stream index
    private var audioStreamIndex: Int = -1

    /// Current frame number
    private var frameNumber: Int = 0

    /// Whether decoder is initialized
    private(set) var isInitialized: Bool = false

    /// Video stream information
    private(set) var videoInfo: VideoStreamInfo?

    /// Audio stream information
    private(set) var audioInfo: AudioStreamInfo?

    // MARK: - Initialization

    /// Initialize decoder with file path
    /// - Parameter filePath: Path to video file
    init(filePath: String) {
        self.filePath = filePath
    }

    deinit {
        cleanup()
    }

    // MARK: - Public Methods

    /// Open and initialize the decoder
    /// - Throws: DecoderError if initialization fails
    func initialize() throws {
        guard !isInitialized else {
            throw DecoderError.alreadyInitialized
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw DecoderError.cannotOpenFile("File not found: \(filePath)")
        }

        // Open input file with explicit C string conversion
        var formatCtx: UnsafeMutablePointer<AVFormatContext>?
        let openResult = filePath.withCString { cString in
            return avformat_open_input(&formatCtx, cString, nil, nil)
        }

        if openResult != 0 {
            var errorBuffer = [Int8](repeating: 0, count: 256)
            av_strerror(openResult, &errorBuffer, 256)
            let errorString = String(cString: errorBuffer)
            throw DecoderError.cannotOpenFile("Failed to open \(filePath): \(errorString)")
        }
        self.formatContext = formatCtx

        // Find stream information
        if avformat_find_stream_info(formatContext, nil) < 0 {
            cleanup()
            throw DecoderError.cannotFindStreamInfo(filePath)
        }

        // Find video and audio streams
        guard let formatCtx = formatContext else {
            throw DecoderError.cannotOpenFile(filePath)
        }

        let numStreams = Int(formatCtx.pointee.nb_streams)
        let streams = formatCtx.pointee.streams

        for i in 0..<numStreams {
            guard let stream = streams?[i] else { continue }
            let codecType = stream.pointee.codecpar.pointee.codec_type

            if codecType == AVMEDIA_TYPE_VIDEO && videoStreamIndex == -1 {
                videoStreamIndex = i
                try initializeVideoStream(stream: stream)
            } else if codecType == AVMEDIA_TYPE_AUDIO && audioStreamIndex == -1 {
                audioStreamIndex = i
                try initializeAudioStream(stream: stream)
            }
        }

        // At least video stream must be present
        guard videoStreamIndex >= 0 else {
            cleanup()
            throw DecoderError.noVideoStream
        }

        isInitialized = true
    }

    /// Decode next frame (video or audio)
    /// - Returns: Tuple of (VideoFrame?, AudioFrame?) or nil if end of file
    /// - Throws: DecoderError if decoding fails
    func decodeNextFrame() throws -> (video: VideoFrame?, audio: AudioFrame?)? {
        guard isInitialized else {
            throw DecoderError.notInitialized
        }

        guard let formatCtx = formatContext else {
            throw DecoderError.notInitialized
        }

        // Allocate packet
        guard let packet = av_packet_alloc() else {
            throw DecoderError.cannotAllocatePacket
        }
        var packetPtr: UnsafeMutablePointer<AVPacket>? = packet
        defer { av_packet_free(&packetPtr) }

        // Read frame from file
        let readResult = av_read_frame(formatCtx, packet)
        if readResult == -541478725 {  // AVERROR_EOF
            return nil  // End of file
        } else if readResult < 0 {
            throw DecoderError.readFrameError(readResult)
        }

        let streamIndex = Int(packet.pointee.stream_index)

        // Decode based on stream type
        if streamIndex == videoStreamIndex {
            let videoFrame = try decodeVideoPacket(packet: packet)
            return (video: videoFrame, audio: nil)
        } else if streamIndex == audioStreamIndex {
            let audioFrame = try decodeAudioPacket(packet: packet)
            return (video: nil, audio: audioFrame)
        }

        // Packet from unknown stream, skip
        return (video: nil, audio: nil)
    }

    /// Seek to specific timestamp
    /// - Parameter timestamp: Target timestamp in seconds
    /// - Throws: DecoderError if seeking fails
    func seek(to timestamp: TimeInterval) throws {
        guard isInitialized else {
            throw DecoderError.notInitialized
        }

        guard let formatCtx = formatContext else {
            throw DecoderError.notInitialized
        }

        // Convert timestamp to stream time base
        let timeBase = formatCtx.pointee.streams[videoStreamIndex]!.pointee.time_base
        let targetPTS = Int64(timestamp * Double(timeBase.den) / Double(timeBase.num))

        // Seek to keyframe
        let seekResult = av_seek_frame(formatCtx, Int32(videoStreamIndex), targetPTS, AVSEEK_FLAG_BACKWARD)
        if seekResult < 0 {
            throw DecoderError.unknown("Seek failed")
        }

        // Flush codec buffers
        if let videoCtx = videoCodecContext {
            avcodec_flush_buffers(videoCtx)
        }
        if let audioCtx = audioCodecContext {
            avcodec_flush_buffers(audioCtx)
        }

        frameNumber = 0
    }

    /// Get duration of video in seconds
    /// - Returns: Duration or nil if not available
    func getDuration() -> TimeInterval? {
        guard let formatCtx = formatContext else { return nil }
        let duration = formatCtx.pointee.duration
        if duration == Int64(bitPattern: 0x8000000000000001) {  // AV_NOPTS_VALUE
            return nil
        }
        return Double(duration) / Double(AV_TIME_BASE)
    }

    // MARK: - Private Methods

    private func initializeVideoStream(stream: UnsafeMutablePointer<AVStream>) throws {
        guard let codecPar = stream.pointee.codecpar else {
            throw DecoderError.codecNotFound("video")
        }

        // Find decoder
        guard let codec = avcodec_find_decoder(codecPar.pointee.codec_id) else {
            throw DecoderError.codecNotFound("video")
        }

        // Allocate codec context
        guard let codecCtx = avcodec_alloc_context3(codec) else {
            throw DecoderError.cannotAllocateCodecContext
        }

        // Copy codec parameters
        if avcodec_parameters_to_context(codecCtx, codecPar) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotCopyCodecParameters
        }

        // Open codec
        if avcodec_open2(codecCtx, codec, nil) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotOpenCodec("video")
        }

        self.videoCodecContext = codecCtx

        // Extract video information
        let width = Int(codecCtx.pointee.width)
        let height = Int(codecCtx.pointee.height)
        let timeBase = stream.pointee.time_base
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

    private func initializeAudioStream(stream: UnsafeMutablePointer<AVStream>) throws {
        guard let codecPar = stream.pointee.codecpar else {
            throw DecoderError.codecNotFound("audio")
        }

        // Find decoder
        guard let codec = avcodec_find_decoder(codecPar.pointee.codec_id) else {
            throw DecoderError.codecNotFound("audio")
        }

        // Allocate codec context
        guard let codecCtx = avcodec_alloc_context3(codec) else {
            throw DecoderError.cannotAllocateCodecContext
        }

        // Copy codec parameters
        if avcodec_parameters_to_context(codecCtx, codecPar) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotCopyCodecParameters
        }

        // Open codec
        if avcodec_open2(codecCtx, codec, nil) < 0 {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = codecCtx
            avcodec_free_context(&ctx)
            throw DecoderError.cannotOpenCodec("audio")
        }

        self.audioCodecContext = codecCtx

        // Extract audio information
        let sampleRate = Int(codecCtx.pointee.sample_rate)
        let channels = Int(codecCtx.pointee.ch_layout.nb_channels)
        let timeBase = stream.pointee.time_base

        self.audioInfo = AudioStreamInfo(
            sampleRate: sampleRate,
            channels: channels,
            codecName: String(cString: avcodec_get_name(codecPar.pointee.codec_id)),
            bitrate: Int(codecPar.pointee.bit_rate),
            timeBase: timeBase
        )
    }

    private func decodeVideoPacket(packet: UnsafeMutablePointer<AVPacket>) throws -> VideoFrame? {
        guard let codecCtx = videoCodecContext else {
            throw DecoderError.notInitialized
        }

        // Send packet to decoder
        let sendResult = avcodec_send_packet(codecCtx, packet)
        if sendResult < 0 {
            throw DecoderError.sendPacketError(sendResult)
        }

        // Allocate frame
        guard let frame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var framePtr: UnsafeMutablePointer<AVFrame>? = frame
        defer { av_frame_free(&framePtr) }

        // Receive frame from decoder
        let receiveResult = avcodec_receive_frame(codecCtx, frame)
        if receiveResult == -541478725 || receiveResult == -11 || receiveResult == -35 {  // AVERROR_EOF or AVERROR(EAGAIN) (macOS: -35, Linux: -11)
            return nil  // Need more packets
        } else if receiveResult < 0 {
            throw DecoderError.receiveFrameError(receiveResult)
        }

        // Convert frame to RGB24
        guard let videoFrame = try convertFrameToRGB(frame: frame) else {
            return nil
        }

        frameNumber += 1
        return videoFrame
    }

    private func decodeAudioPacket(packet: UnsafeMutablePointer<AVPacket>) throws -> AudioFrame? {
        guard let codecCtx = audioCodecContext else {
            throw DecoderError.notInitialized
        }

        // Send packet to decoder
        let sendResult = avcodec_send_packet(codecCtx, packet)
        if sendResult < 0 {
            throw DecoderError.sendPacketError(sendResult)
        }

        // Allocate frame
        guard let frame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var framePtr: UnsafeMutablePointer<AVFrame>? = frame
        defer { av_frame_free(&framePtr) }

        // Receive frame from decoder
        let receiveResult = avcodec_receive_frame(codecCtx, frame)
        if receiveResult == -541478725 || receiveResult == -11 || receiveResult == -35 {  // AVERROR_EOF or AVERROR(EAGAIN) (macOS: -35, Linux: -11)
            return nil  // Need more packets
        } else if receiveResult < 0 {
            throw DecoderError.receiveFrameError(receiveResult)
        }

        // Convert frame to AudioFrame
        return convertFrameToAudio(frame: frame)
    }

    private func convertFrameToRGB(frame: UnsafeMutablePointer<AVFrame>) throws -> VideoFrame? {
        guard let codecCtx = videoCodecContext, let videoInfo = videoInfo else {
            throw DecoderError.notInitialized
        }

        let width = Int(frame.pointee.width)
        let height = Int(frame.pointee.height)

        // Initialize scaler if needed
        if scalerContext == nil {
            scalerContext = sws_getContext(
                Int32(width),
                Int32(height),
                codecCtx.pointee.pix_fmt,
                Int32(width),
                Int32(height),
                AV_PIX_FMT_BGRA,
                Int32(SWS_BILINEAR.rawValue),
                nil, nil, nil
            )
        }

        guard let swsCtx = scalerContext else {
            throw DecoderError.scalerInitError
        }

        // Allocate RGB frame
        guard let rgbFrame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        var rgbFramePtr: UnsafeMutablePointer<AVFrame>? = rgbFrame
        defer { av_frame_free(&rgbFramePtr) }

        rgbFrame.pointee.format = AV_PIX_FMT_BGRA.rawValue
        rgbFrame.pointee.width = Int32(width)
        rgbFrame.pointee.height = Int32(height)

        if av_frame_get_buffer(rgbFrame, 32) < 0 {
            throw DecoderError.cannotAllocateFrame
        }

        // Convert pixel format
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

        // Copy RGB data
        let lineSize = Int(rgbFrame.pointee.linesize.0)
        let dataSize = lineSize * height
        let data = Data(bytes: rgbFrame.pointee.data.0!, count: dataSize)

        // Calculate timestamp
        let pts = frame.pointee.pts
        let timeBase = videoInfo.timeBase
        let timestamp = Double(pts) * Double(timeBase.num) / Double(timeBase.den)

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

    private func convertFrameToAudio(frame: UnsafeMutablePointer<AVFrame>) -> AudioFrame? {
        guard let audioInfo = audioInfo else {
            return nil
        }

        let sampleCount = Int(frame.pointee.nb_samples)
        let channels = Int(frame.pointee.ch_layout.nb_channels)

        // Determine format
        let format: AudioFormat
        switch frame.pointee.format {
        case AV_SAMPLE_FMT_FLTP.rawValue:
            format = .floatPlanar
        case AV_SAMPLE_FMT_FLT.rawValue:
            format = .floatInterleaved
        case AV_SAMPLE_FMT_S16P.rawValue:
            format = .s16Planar
        case AV_SAMPLE_FMT_S16.rawValue:
            format = .s16Interleaved
        default:
            return nil  // Unsupported format
        }

        // Copy audio data
        let bytesPerSample = format.bytesPerSample
        let dataSize = sampleCount * channels * bytesPerSample
        var data = Data(count: dataSize)

        if format.isInterleaved {
            // Interleaved: copy directly
            data.withUnsafeMutableBytes { (destBytes: UnsafeMutableRawBufferPointer) in
                if let destPtr = destBytes.baseAddress {
                    memcpy(destPtr, frame.pointee.data.0, dataSize)
                }
            }
        } else {
            // Planar: copy each channel
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

        // Calculate timestamp
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

    private func cleanup() {
        if let swsCtx = scalerContext {
            sws_freeContext(swsCtx)
            scalerContext = nil
        }

        if videoCodecContext != nil {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = videoCodecContext
            avcodec_free_context(&ctx)
            videoCodecContext = nil
        }

        if audioCodecContext != nil {
            var ctx: UnsafeMutablePointer<AVCodecContext>? = audioCodecContext
            avcodec_free_context(&ctx)
            audioCodecContext = nil
        }

        if formatContext != nil {
            var ctx: UnsafeMutablePointer<AVFormatContext>? = formatContext
            avformat_close_input(&ctx)
            formatContext = nil
        }

        isInitialized = false
    }
}

// MARK: - Supporting Types

/// Video stream information
struct VideoStreamInfo {
    let width: Int
    let height: Int
    let frameRate: Double
    let codecName: String
    let bitrate: Int
    let timeBase: AVRational
}

/// Audio stream information
struct AudioStreamInfo {
    let sampleRate: Int
    let channels: Int
    let codecName: String
    let bitrate: Int
    let timeBase: AVRational
}
