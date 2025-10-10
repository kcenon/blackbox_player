//
//  VideoFile.swift
//  BlackboxPlayer
//
//  Model for dashcam video file (potentially multi-channel)
//

import Foundation

/// Dashcam video file with metadata and channel information
struct VideoFile: Codable, Equatable, Identifiable, Hashable {
    /// Unique identifier
    let id: UUID

    /// Recording start timestamp
    let timestamp: Date

    /// Event type (normal, impact, parking, etc.)
    let eventType: EventType

    /// Video duration in seconds
    let duration: TimeInterval

    /// All video channels (front, rear, left, right, interior)
    let channels: [ChannelInfo]

    /// Associated metadata (GPS, G-Sensor)
    let metadata: VideoMetadata

    /// Base file path (without channel suffix)
    let basePath: String

    /// Whether this file is marked as favorite
    let isFavorite: Bool

    /// User-added notes/comments
    let notes: String?

    /// File is corrupted or damaged
    let isCorrupted: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        timestamp: Date,
        eventType: EventType,
        duration: TimeInterval,
        channels: [ChannelInfo],
        metadata: VideoMetadata = VideoMetadata(),
        basePath: String,
        isFavorite: Bool = false,
        notes: String? = nil,
        isCorrupted: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.duration = duration
        self.channels = channels
        self.metadata = metadata
        self.basePath = basePath
        self.isFavorite = isFavorite
        self.notes = notes
        self.isCorrupted = isCorrupted
    }

    // MARK: - Channel Access

    /// Get channel by position
    /// - Parameter position: Camera position
    /// - Returns: Channel info or nil
    func channel(for position: CameraPosition) -> ChannelInfo? {
        return channels.first { $0.position == position }
    }

    /// Front camera channel
    var frontChannel: ChannelInfo? {
        return channel(for: .front)
    }

    /// Rear camera channel
    var rearChannel: ChannelInfo? {
        return channel(for: .rear)
    }

    /// Check if specific channel exists
    /// - Parameter position: Camera position
    /// - Returns: True if channel exists
    func hasChannel(_ position: CameraPosition) -> Bool {
        return channel(for: position) != nil
    }

    /// Number of available channels
    var channelCount: Int {
        return channels.count
    }

    /// Array of enabled channels only
    var enabledChannels: [ChannelInfo] {
        return channels.filter { $0.isEnabled }
    }

    /// Check if this is a multi-channel recording
    var isMultiChannel: Bool {
        return channels.count > 1
    }

    // MARK: - File Properties

    /// Total size of all channel files
    var totalFileSize: UInt64 {
        return channels.reduce(0) { $0 + $1.fileSize }
    }

    /// Total file size as human-readable string
    var totalFileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalFileSize))
    }

    /// Base filename (extracted from basePath)
    var baseFilename: String {
        return (basePath as NSString).lastPathComponent
    }

    /// Duration as formatted string (HH:MM:SS)
    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Timestamp as formatted string
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    /// Short timestamp (date only)
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }

    /// Short timestamp (time only)
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    // MARK: - Metadata Access

    /// Check if video has GPS data
    var hasGPSData: Bool {
        return metadata.hasGPSData
    }

    /// Check if video has G-Sensor data
    var hasAccelerationData: Bool {
        return metadata.hasAccelerationData
    }

    /// Check if video contains impact events
    var hasImpactEvents: Bool {
        return metadata.hasImpactEvents
    }

    /// Number of impact events detected
    var impactEventCount: Int {
        return metadata.impactEvents.count
    }

    // MARK: - Validation

    /// Check if video file is valid (has at least one channel)
    var isValid: Bool {
        return !channels.isEmpty && channels.allSatisfy { $0.isValid }
    }

    /// Check if video is playable (valid and not corrupted)
    var isPlayable: Bool {
        return isValid && !isCorrupted
    }

    // MARK: - Mutations (return new instance)

    /// Create a copy with updated favorite status
    /// - Parameter isFavorite: New favorite status
    /// - Returns: New VideoFile instance
    func withFavorite(_ isFavorite: Bool) -> VideoFile {
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }

    /// Create a copy with updated notes
    /// - Parameter notes: New notes text
    /// - Returns: New VideoFile instance
    func withNotes(_ notes: String?) -> VideoFile {
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }

    /// Create a copy with enabled/disabled channel
    /// - Parameters:
    ///   - position: Camera position
    ///   - enabled: New enabled status
    /// - Returns: New VideoFile instance
    func withChannel(_ position: CameraPosition, enabled: Bool) -> VideoFile {
        let updatedChannels = channels.map { channel -> ChannelInfo in
            if channel.position == position {
                return ChannelInfo(
                    id: channel.id,
                    position: channel.position,
                    filePath: channel.filePath,
                    width: channel.width,
                    height: channel.height,
                    frameRate: channel.frameRate,
                    bitrate: channel.bitrate,
                    codec: channel.codec,
                    audioCodec: channel.audioCodec,
                    isEnabled: enabled,
                    fileSize: channel.fileSize
                )
            }
            return channel
        }

        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: updatedChannels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }
}

// MARK: - Sample Data

extension VideoFile {
    /// Sample normal recording (5 channels)
    static let normal5Channel = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 60.0,
        channels: ChannelInfo.allSampleChannels,
        metadata: VideoMetadata.sample,
        basePath: "normal/2025_01_10_09_00_00"
    )

    /// Sample impact recording (2 channels)
    static let impact2Channel = VideoFile(
        timestamp: Date().addingTimeInterval(-3600),
        eventType: .impact,
        duration: 30.0,
        channels: [ChannelInfo.frontHD, ChannelInfo.rearHD],
        metadata: VideoMetadata.withImpact,
        basePath: "event/2025_01_10_10_30_15"
    )

    /// Sample parking recording (1 channel)
    static let parking1Channel = VideoFile(
        timestamp: Date().addingTimeInterval(-7200),
        eventType: .parking,
        duration: 10.0,
        channels: [ChannelInfo.frontHD],
        metadata: VideoMetadata.gpsOnly,
        basePath: "parking/2025_01_10_18_00_00"
    )

    /// Sample favorite recording
    static let favoriteRecording = VideoFile(
        timestamp: Date().addingTimeInterval(-10800),
        eventType: .manual,
        duration: 120.0,
        channels: [ChannelInfo.frontHD, ChannelInfo.rearHD],
        metadata: VideoMetadata.sample,
        basePath: "manual/2025_01_10_15_00_00",
        isFavorite: true,
        notes: "Beautiful sunset drive"
    )

    /// Sample corrupted file
    static let corruptedFile = VideoFile(
        timestamp: Date().addingTimeInterval(-14400),
        eventType: .normal,
        duration: 0.0,
        channels: [ChannelInfo.frontHD],
        metadata: VideoMetadata.empty,
        basePath: "normal/2025_01_10_12_00_00",
        isCorrupted: true
    )

    /// Array of all sample files
    static let allSamples: [VideoFile] = [
        normal5Channel,
        impact2Channel,
        parking1Channel,
        favoriteRecording,
        corruptedFile
    ]
}
