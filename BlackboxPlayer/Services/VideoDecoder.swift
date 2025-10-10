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

    /// FFmpeg format context (opaque pointer)
    private var formatContext: OpaquePointer?

    /// Video codec context
    private var videoCodecContext: OpaquePointer?

    /// Audio codec context
    private var audioCodecContext: OpaquePointer?

    /// Scaler context for pixel format conversion
    private var scalerContext: OpaquePointer?

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

        // Open input file
        var formatCtx: OpaquePointer?
        if avformat_open_input(&formatCtx, filePath, nil, nil) != 0 {
            throw DecoderError.cannotOpenFile(filePath)
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
        var streams = formatCtx.pointee.streams

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
        defer { av_packet_free(&(UnsafeMutablePointer(mutating: packet))) }

        // Read frame from file
        let readResult = av_read_frame(formatCtx, packet)
        if readResult == AVERROR_EOF {
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
        if duration == AV_NOPTS_VALUE {
            return nil
        }
        return Double(duration) / Double(AV_TIME_BASE)
    }

    // MARK: - Private Methods

    private func initializeVideoStream(stream: UnsafeMutablePointer<AVStream>) throws {
        let codecPar = stream.pointee.codecpar

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
            avcodec_free_context(&(UnsafeMutablePointer(mutating: codecCtx)))
            throw DecoderError.cannotCopyCodecParameters
        }

        // Open codec
        if avcodec_open2(codecCtx, codec, nil) < 0 {
            avcodec_free_context(&(UnsafeMutablePointer(mutating: codecCtx)))
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
        let codecPar = stream.pointee.codecpar

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
            avcodec_free_context(&(UnsafeMutablePointer(mutating: codecCtx)))
            throw DecoderError.cannotCopyCodecParameters
        }

        // Open codec
        if avcodec_open2(codecCtx, codec, nil) < 0 {
            avcodec_free_context(&(UnsafeMutablePointer(mutating: codecCtx)))
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
        var sendResult = avcodec_send_packet(codecCtx, packet)
        if sendResult < 0 {
            throw DecoderError.sendPacketError(sendResult)
        }

        // Allocate frame
        guard let frame = av_frame_alloc() else {
            throw DecoderError.cannotAllocateFrame
        }
        defer { av_frame_free(&(UnsafeMutablePointer(mutating: frame))) }

        // Receive frame from decoder
        let receiveResult = avcodec_receive_frame(codecCtx, frame)
        if receiveResult == AVERROR_EOF || receiveResult == Int32(bitPattern: UInt32(AVERROR(EAGAIN))) {
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
        defer { av_frame_free(&(UnsafeMutablePointer(mutating: frame))) }

        // Receive frame from decoder
        let receiveResult = avcodec_receive_frame(codecCtx, frame)
        if receiveResult == AVERROR_EOF || receiveResult == Int32(bitPattern: UInt32(AVERROR(EAGAIN))) {
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
                AV_PIX_FMT_RGB24,
                SWS_BILINEAR,
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
        defer { av_frame_free(&(UnsafeMutablePointer(mutating: rgbFrame))) }

        rgbFrame.pointee.format = AV_PIX_FMT_RGB24.rawValue
        rgbFrame.pointee.width = Int32(width)
        rgbFrame.pointee.height = Int32(height)

        if av_frame_get_buffer(rgbFrame, 32) < 0 {
            throw DecoderError.cannotAllocateFrame
        }

        // Convert pixel format
        sws_scale(
            swsCtx,
            frame.pointee.data,
            frame.pointee.linesize,
            0,
            Int32(height),
            rgbFrame.pointee.data,
            rgbFrame.pointee.linesize
        )

        // Copy RGB data
        let lineSize = Int(rgbFrame.pointee.linesize.0)
        let dataSize = lineSize * height
        let data = Data(bytes: rgbFrame.pointee.data.0!, count: dataSize)

        // Calculate timestamp
        let pts = frame.pointee.pts
        let timeBase = videoInfo.timeBase
        let timestamp = Double(pts) * Double(timeBase.num) / Double(timeBase.den)

        let isKeyFrame = frame.pointee.key_frame == 1

        return VideoFrame(
            timestamp: timestamp,
            width: width,
            height: height,
            pixelFormat: .rgb24,
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
            data.withUnsafeMutableBytes { destBytes in
                if let destPtr = destBytes.baseAddress {
                    memcpy(destPtr, frame.pointee.data.0, dataSize)
                }
            }
        } else {
            // Planar: copy each channel
            let bytesPerChannel = sampleCount * bytesPerSample
            data.withUnsafeMutableBytes { destBytes in
                if let destPtr = destBytes.baseAddress {
                    for ch in 0..<channels {
                        let offset = ch * bytesPerChannel
                        memcpy(destPtr + offset, frame.pointee.data[ch], bytesPerChannel)
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

        if let videoCtx = videoCodecContext {
            var ctx = UnsafeMutablePointer(mutating: videoCtx)
            avcodec_free_context(&ctx)
            videoCodecContext = nil
        }

        if let audioCtx = audioCodecContext {
            var ctx = UnsafeMutablePointer(mutating: audioCtx)
            avcodec_free_context(&ctx)
            audioCodecContext = nil
        }

        if let formatCtx = formatContext {
            var ctx = UnsafeMutablePointer(mutating: formatCtx)
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
