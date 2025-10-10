//
//  ChannelInfo.swift
//  BlackboxPlayer
//
//  Model for video channel/camera information
//

import Foundation

/// Information about a video channel/camera in a multi-camera system
struct ChannelInfo: Codable, Equatable, Identifiable, Hashable {
    /// Unique identifier for this channel
    let id: UUID

    /// Camera position/type
    let position: CameraPosition

    /// File path to the video file for this channel
    let filePath: String

    /// Video resolution width in pixels
    let width: Int

    /// Video resolution height in pixels
    let height: Int

    /// Frame rate in frames per second
    let frameRate: Double

    /// Video bitrate in bits per second (optional)
    let bitrate: Int?

    /// Video codec (e.g., "h264", "h265")
    let codec: String?

    /// Audio codec (e.g., "mp3", "aac") (optional)
    let audioCodec: String?

    /// Channel is enabled/active
    let isEnabled: Bool

    /// File size in bytes
    let fileSize: UInt64

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        position: CameraPosition,
        filePath: String,
        width: Int,
        height: Int,
        frameRate: Double,
        bitrate: Int? = nil,
        codec: String? = nil,
        audioCodec: String? = nil,
        isEnabled: Bool = true,
        fileSize: UInt64 = 0
    ) {
        self.id = id
        self.position = position
        self.filePath = filePath
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.bitrate = bitrate
        self.codec = codec
        self.audioCodec = audioCodec
        self.isEnabled = isEnabled
        self.fileSize = fileSize
    }

    // MARK: - Computed Properties

    /// Resolution as a formatted string (e.g., "1920x1080")
    var resolutionString: String {
        return "\(width)x\(height)"
    }

    /// Common resolution name (e.g., "Full HD", "4K")
    var resolutionName: String {
        switch (width, height) {
        case (3840, 2160):
            return "4K UHD"
        case (2560, 1440):
            return "2K QHD"
        case (1920, 1080):
            return "Full HD"
        case (1280, 720):
            return "HD"
        case (640, 480):
            return "SD"
        default:
            return resolutionString
        }
    }

    /// Aspect ratio as a decimal
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }

    /// Aspect ratio as a formatted string (e.g., "16:9")
    var aspectRatioString: String {
        let ratio = aspectRatio
        if abs(ratio - 16.0/9.0) < 0.01 {
            return "16:9"
        } else if abs(ratio - 4.0/3.0) < 0.01 {
            return "4:3"
        } else if abs(ratio - 21.0/9.0) < 0.01 {
            return "21:9"
        } else {
            return String(format: "%.2f:1", ratio)
        }
    }

    /// Frame rate as formatted string
    var frameRateString: String {
        if frameRate == floor(frameRate) {
            return "\(Int(frameRate)) fps"
        } else {
            return String(format: "%.2f fps", frameRate)
        }
    }

    /// Bitrate as human-readable string
    var bitrateString: String? {
        guard let bitrate = bitrate else { return nil }

        let mbps = Double(bitrate) / 1_000_000
        if mbps >= 1.0 {
            return String(format: "%.1f Mbps", mbps)
        } else {
            let kbps = Double(bitrate) / 1000
            return String(format: "%.0f Kbps", kbps)
        }
    }

    /// File size as human-readable string
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }

    /// Filename extracted from path
    var filename: String {
        return (filePath as NSString).lastPathComponent
    }

    /// Check if this is a high-resolution channel (>= 1080p)
    var isHighResolution: Bool {
        return height >= 1080
    }

    /// Check if audio is available
    var hasAudio: Bool {
        return audioCodec != nil
    }

    // MARK: - Validation

    /// Validate that all required properties are valid
    var isValid: Bool {
        return width > 0 &&
               height > 0 &&
               frameRate > 0 &&
               !filePath.isEmpty
    }
}

// MARK: - Sample Data

extension ChannelInfo {
    /// Sample front camera (Full HD)
    static let frontHD = ChannelInfo(
        position: .front,
        filePath: "normal/2025_01_10_09_00_00_F.mp4",
        width: 1920,
        height: 1080,
        frameRate: 30.0,
        bitrate: 8_000_000,
        codec: "h264",
        audioCodec: "mp3",
        fileSize: 100_000_000
    )

    /// Sample rear camera (HD)
    static let rearHD = ChannelInfo(
        position: .rear,
        filePath: "normal/2025_01_10_09_00_00_R.mp4",
        width: 1280,
        height: 720,
        frameRate: 30.0,
        bitrate: 4_000_000,
        codec: "h264",
        fileSize: 50_000_000
    )

    /// Sample left camera (HD)
    static let leftHD = ChannelInfo(
        position: .left,
        filePath: "normal/2025_01_10_09_00_00_L.mp4",
        width: 1280,
        height: 720,
        frameRate: 30.0,
        bitrate: 4_000_000,
        codec: "h264",
        fileSize: 50_000_000
    )

    /// Sample right camera (HD)
    static let rightHD = ChannelInfo(
        position: .right,
        filePath: "normal/2025_01_10_09_00_00_Ri.mp4",
        width: 1280,
        height: 720,
        frameRate: 30.0,
        bitrate: 4_000_000,
        codec: "h264",
        fileSize: 50_000_000
    )

    /// Sample interior camera (HD)
    static let interiorHD = ChannelInfo(
        position: .interior,
        filePath: "normal/2025_01_10_09_00_00_I.mp4",
        width: 1280,
        height: 720,
        frameRate: 30.0,
        bitrate: 4_000_000,
        codec: "h264",
        fileSize: 50_000_000
    )

    /// Array of all sample channels
    static let allSampleChannels: [ChannelInfo] = [
        frontHD,
        rearHD,
        leftHD,
        rightHD,
        interiorHD
    ]
}
