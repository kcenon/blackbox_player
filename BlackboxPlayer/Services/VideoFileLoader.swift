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

    /// Metadata extractor
    private let metadataExtractor: MetadataExtractor

    // MARK: - Initialization

    init() {
        self.metadataExtractor = MetadataExtractor()
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

        // Extract metadata from first channel (front camera if available)
        let frontChannel = group.files.first { $0.position == .front } ?? group.files.first
        let metadata: VideoMetadata
        if let frontChannel = frontChannel,
           let extractedMetadata = metadataExtractor.extractMetadata(from: frontChannel.url.path) {
            metadata = extractedMetadata
        } else {
            metadata = VideoMetadata()
        }

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

        // Check for corruption
        let isCorrupted = videoFile.checkCorruption()
        if isCorrupted {
            // Return corrupted VideoFile for display with warning
            return VideoFile(
                id: videoFile.id,
                timestamp: videoFile.timestamp,
                eventType: videoFile.eventType,
                duration: videoFile.duration,
                channels: videoFile.channels,
                metadata: videoFile.metadata,
                basePath: videoFile.basePath,
                isFavorite: false,
                notes: nil,
                isCorrupted: true
            )
        }

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
        // Check if file exists and has valid extension
        let fileExtension = url.pathExtension.lowercased()
        let validExtensions = ["mp4", "mov", "avi", "mkv"]
        return FileManager.default.fileExists(atPath: url.path) && validExtensions.contains(fileExtension)
    }

    // MARK: - Private Methods

    private func extractChannelInfo(from fileInfo: VideoFileInfo) -> ChannelInfo? {
        let filePath = fileInfo.url.path

        // Check if file exists first
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("Warning: File does not exist: \(filePath)")
            return nil
        }

        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: filePath) else {
            print("Warning: File is not readable: \(filePath)")
            return nil
        }

        // TODO: Implement FFmpeg video analysis
        // For now, use default values based on common dashcam specs
        let width = 1920
        let height = 1080
        let frameRate = 30.0
        let bitrate: Int? = nil
        let codec = "h264"
        let audioCodec: String? = "aac"
        let duration: TimeInterval = 60.0 // Default 1 minute

        // Create ChannelInfo with default values
        return ChannelInfo(
            id: UUID(),
            position: fileInfo.position,
            filePath: filePath,
            width: width,
            height: height,
            frameRate: frameRate,
            bitrate: bitrate,
            codec: codec,
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
