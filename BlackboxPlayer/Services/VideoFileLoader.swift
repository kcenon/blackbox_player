//
//  VideoFileLoader.swift
//  BlackboxPlayer
//
//  Service for loading video file information and creating VideoFile models
//

import Foundation

/// Service for extracting video information and creating VideoFile models
class VideoFileLoader {
    // MARK: - Properties

    /// Metadata extractor (will be set in Step 5)
    private var metadataExtractor: MetadataExtractor?

    // MARK: - Initialization

    init() {
        // Metadata extractor will be initialized in Step 5
    }

    // MARK: - Public Methods

    /// Load VideoFile from a group of video files
    /// - Parameter group: Group of video files (multi-channel)
    /// - Returns: VideoFile model or nil if loading fails
    func loadVideoFile(from group: VideoFileGroup) -> VideoFile? {
        guard !group.files.isEmpty else { return nil }

        // Extract information from each channel
        var channels: [ChannelInfo] = []

        for fileInfo in group.files {
            if let channelInfo = extractChannelInfo(from: fileInfo) {
                channels.append(channelInfo)
            }
        }

        guard !channels.isEmpty else { return nil }

        // Get duration from first channel
        let duration = channels.first?.duration ?? 0

        // Create metadata (empty for now, will be populated in Step 5)
        let metadata = VideoMetadata()

        // Create VideoFile
        let videoFile = VideoFile(
            id: UUID(),
            timestamp: group.timestamp,
            eventType: group.eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: group.basePath,
            isFavorite: false,
            notes: nil,
            isCorrupted: false
        )

        return videoFile
    }

    /// Load multiple VideoFiles from groups
    /// - Parameter groups: Array of video file groups
    /// - Returns: Array of VideoFile models
    func loadVideoFiles(from groups: [VideoFileGroup]) -> [VideoFile] {
        return groups.compactMap { loadVideoFile(from: $0) }
    }

    /// Quick check if file is valid video
    /// - Parameter url: File URL
    /// - Returns: true if file is valid and can be opened
    func isValidVideoFile(_ url: URL) -> Bool {
        var formatContext: OpaquePointer?
        defer {
            if let ctx = formatContext {
                var mutableCtx = UnsafeMutablePointer(mutating: ctx)
                avformat_close_input(&mutableCtx)
            }
        }

        return avformat_open_input(&formatContext, url.path, nil, nil) == 0
    }

    // MARK: - Private Methods

    private func extractChannelInfo(from fileInfo: VideoFileInfo) -> ChannelInfo? {
        let filePath = fileInfo.url.path

        // Open video file with FFmpeg
        var formatContext: OpaquePointer?
        guard avformat_open_input(&formatContext, filePath, nil, nil) == 0 else {
            return nil
        }
        defer {
            if let ctx = formatContext {
                var mutableCtx = UnsafeMutablePointer(mutating: ctx)
                avformat_close_input(&mutableCtx)
            }
        }

        // Find stream info
        guard avformat_find_stream_info(formatContext, nil) >= 0,
              let formatCtx = formatContext else {
            return nil
        }

        // Find video stream
        let numStreams = Int(formatCtx.pointee.nb_streams)
        var streams = formatCtx.pointee.streams

        var videoStreamIndex = -1
        var videoStream: UnsafeMutablePointer<AVStream>?

        for i in 0..<numStreams {
            guard let stream = streams?[i] else { continue }
            let codecType = stream.pointee.codecpar.pointee.codec_type

            if codecType == AVMEDIA_TYPE_VIDEO && videoStreamIndex == -1 {
                videoStreamIndex = i
                videoStream = stream
                break
            }
        }

        guard let stream = videoStream else {
            return nil
        }

        let codecPar = stream.pointee.codecpar.pointee

        // Extract video information
        let width = Int(codecPar.width)
        let height = Int(codecPar.height)
        let frameRate = av_q2d(stream.pointee.r_frame_rate)
        let bitrate = Int(codecPar.bit_rate)
        let codecName = String(cString: avcodec_get_name(codecPar.codec_id))

        // Check for audio stream
        var hasAudio = false
        var audioCodec: String?

        for i in 0..<numStreams {
            guard let stream = streams?[i] else { continue }
            let codecType = stream.pointee.codecpar.pointee.codec_type

            if codecType == AVMEDIA_TYPE_AUDIO {
                hasAudio = true
                audioCodec = String(cString: avcodec_get_name(stream.pointee.codecpar.pointee.codec_id))
                break
            }
        }

        // Get duration
        let durationValue = formatCtx.pointee.duration
        let duration: TimeInterval
        if durationValue != AV_NOPTS_VALUE {
            duration = Double(durationValue) / Double(AV_TIME_BASE)
        } else {
            // Try to get from stream
            let streamDuration = stream.pointee.duration
            if streamDuration != AV_NOPTS_VALUE {
                let timeBase = stream.pointee.time_base
                duration = Double(streamDuration) * Double(timeBase.num) / Double(timeBase.den)
            } else {
                duration = 0
            }
        }

        // Create ChannelInfo
        return ChannelInfo(
            id: UUID(),
            position: fileInfo.position,
            filePath: filePath,
            width: width,
            height: height,
            frameRate: frameRate,
            bitrate: bitrate > 0 ? bitrate : nil,
            codec: codecName,
            audioCodec: audioCodec,
            isEnabled: true,
            fileSize: fileInfo.fileSize,
            duration: duration
        )
    }
}

// MARK: - VideoFile Extension

extension VideoFile {
    /// Check if video file is corrupted
    /// - Returns: true if file appears corrupted
    func checkCorruption() -> Bool {
        // Check if any channel file doesn't exist
        for channel in channels {
            if !FileManager.default.fileExists(atPath: channel.filePath) {
                return true
            }
        }

        // Check if duration is invalid
        if duration <= 0 {
            return true
        }

        // Check if all channels have zero file size
        if channels.allSatisfy({ $0.fileSize == 0 }) {
            return true
        }

        return false
    }
}
