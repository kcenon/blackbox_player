/// @file ChannelInfo.swift
/// @brief Blackbox video channel/camera information model
/// @author BlackboxPlayer Development Team
///
/// Model for video channel/camera information

import Foundation

/*
 ═══════════════════════════════════════════════════════════════════════════════
 ChannelInfo - Video Channel Information
 ═══════════════════════════════════════════════════════════════════════════════

 【Overview】
 ChannelInfo is a struct that represents information about individual channels (cameras)
 in a multi-camera blackbox system. It stores and manages video specifications for each
 channel, including resolution, frame rate, codec, file path, etc.

 【What is a Video Channel?】

 A channel refers to each camera in the blackbox.

 Multi-channel blackbox configuration examples:
 - 1 channel: Front camera only (basic)
 - 2 channels: Front + Rear (most common)
 - 3 channels: Front + Rear + Interior
 - 4 channels: Front + Rear + Left + Right
 - 5 channels: Front + Rear + Left + Right + Interior (premium)

 Each channel is recorded as an independent video file:
 2025_01_10_09_00_00_F.mp4  ← Front channel
 2025_01_10_09_00_00_R.mp4  ← Rear channel
 2025_01_10_09_00_00_I.mp4  ← Interior channel

 【Video Resolution】

 Resolution represents the number of pixels in the video.

 Resolution notation:
 Width × Height
 Example: 1920 × 1080 (Full HD)

 Common resolution grades:

 4K UHD:    3840 × 2160  (8.29 million pixels) ★★★★★ Premium
 2K QHD:    2560 × 1440  (3.69 million pixels) ★★★★ High-end
 Full HD:   1920 × 1080  (2.07 million pixels) ★★★ Standard
 HD:        1280 × 720   (0.92 million pixels) ★★ Budget
 SD:         640 × 480   (0.31 million pixels) ★ Legacy

 Comparison:
 ┌──────────────────────────────────┐
 │                                  │  4K (3840×2160)
 │                                  │
 │      ┌──────────────────┐        │
 │      │                  │        │  Full HD (1920×1080)
 │      │    ┌──────┐      │        │
 │      │    │      │      │        │  HD (1280×720)
 │      │    └──────┘      │        │
 │      └──────────────────┘        │
 └──────────────────────────────────┘

 Higher resolution means:
 - Sharper video quality
 - Larger file size
 - More storage space required
 - Higher processing power needed

 【Aspect Ratio】

 Aspect ratio is the ratio of width to height.

 Common ratios:
 16:9  - Widescreen (standard blackbox, TV, monitor)
 4:3   - Legacy ratio (old blackbox, old TV)
 21:9  - Ultra-wide (cinema, premium monitors)

 Ratio comparison:
 16:9  ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬  (wide)
 ▬▬▬▬▬▬▬▬▬▬▬

 4:3   ▬▬▬▬▬▬▬▬▬▬▬▬      (closer to square)
 ▬▬▬▬▬▬▬▬▬

 Calculation examples:
 1920 ÷ 1080 = 1.777... ≈ 16/9 = 1.777...
 1280 ÷ 720  = 1.777... ≈ 16/9
 1024 ÷ 768  = 1.333... ≈ 4/3 = 1.333...

 【Frame Rate】

 Frame rate is the number of frames (still images) displayed per second.
 Unit: fps (frames per second)

 Common frame rates:
 60 fps  - Very smooth video (premium blackbox, gaming, slow motion)
 30 fps  - Standard video (most blackboxes, YouTube)
 24 fps  - Cinema standard
 15 fps  - Low-power mode (parking mode)

 Frame rate and smoothness:
 15 fps:  ●   ●   ●   ●      (choppy)
 30 fps:  ●●  ●●  ●●  ●●     (natural)
 60 fps:  ●●●●●●●●●●●●●●●● (very smooth)

 Advantages of higher frame rate:
 - Smoother video
 - Better capture of fast motion (accident moments)
 - Slow-motion playback possible

 Disadvantages:
 - Larger file size
 - More processing power required

 【Bitrate】

 Bitrate is the amount of data stored per second.
 Unit: bps (bits per second)

 Unit conversion:
 1 Kbps = 1,000 bps
 1 Mbps = 1,000,000 bps = 1,000 Kbps

 Common bitrates:

 Full HD (1920×1080):
 - Low quality:    4 Mbps
 - Standard:       8 Mbps  ← Most blackboxes
 - High quality:  12 Mbps

 4K (3840×2160):
 - Low quality:   16 Mbps
 - Standard:      24 Mbps
 - High quality:  40 Mbps

 Bitrate and quality:
 Low bitrate (4 Mbps):
 - Heavy compression → Lower quality
 - Smaller file size
 - Storage savings

 High bitrate (12 Mbps):
 - Light compression → Sharp quality
 - Larger file size
 - More storage space required

 【Video Codec】

 Codec is a technology for compressing/decompressing video.
 Codec = Coder (compression) + Decoder (decompression)

 Common video codecs:

 H.264 (AVC):
 - Most widely used
 - Best compatibility
 - Moderate compression ratio
 - Used by most blackboxes

 H.265 (HEVC):
 - 2x more efficient compression than H.264
 - Half the file size at same quality
 - Used by modern blackboxes
 - May not play on some older devices

 Compression ratio comparison (same quality):
 H.264: ████████ (8 MB)
 H.265: ████     (4 MB) ← 50% smaller

 【Audio Codec】

 Audio compression technology.

 AAC:
 - High-quality compression
 - Optimized for Apple devices
 - Used by modern blackboxes

 MP3:
 - Universal codec
 - Best compatibility
 - Used by older blackboxes

 【File Size Calculation Example】

 Full HD, 30 fps, 8 Mbps, 1 minute recording:
 8 Mbps = 8,000,000 bits/sec
 = 1,000,000 bytes/sec (8 bits = 1 byte)
 = 1 MB/sec

 1 minute = 60 seconds
 File size = 1 MB/sec × 60 sec = 60 MB

 1 hour recording:
 60 MB/min × 60 min = 3,600 MB = 3.6 GB

 32GB SD card recording time:
 32 GB ÷ 3.6 GB/hour ≈ 8.9 hours

 【ChannelInfo Usage Example】

 ```swift
 // Front camera Full HD channel
 let frontChannel = ChannelInfo(
 position: .front,
 filePath: "normal/2025_01_10_09_00_00_F.mp4",
 width: 1920,
 height: 1080,
 frameRate: 30.0,
 bitrate: 8_000_000,  // 8 Mbps
 codec: "h264",
 audioCodec: "mp3",
 fileSize: 100_000_000  // 100 MB
 )

 // Display channel information
 print("Camera position: \(frontChannel.position.displayName)")
 print("Resolution: \(frontChannel.resolutionName) (\(frontChannel.resolutionString))")
 print("Aspect ratio: \(frontChannel.aspectRatioString)")
 print("Frame rate: \(frontChannel.frameRateString)")
 print("Bitrate: \(frontChannel.bitrateString ?? "N/A")")
 print("File size: \(frontChannel.fileSizeString)")
 print("High resolution: \(frontChannel.isHighResolution ? "Yes" : "No")")
 print("Audio: \(frontChannel.hasAudio ? "Yes" : "No")")
 ```

 ═══════════════════════════════════════════════════════════════════════════════
 */

/// @struct ChannelInfo
/// @brief Video channel/camera information
///
/// Information about a video channel/camera in a multi-camera system
///
/// Struct representing information about an individual video channel (camera) in a multi-camera system.
///
/// **Key Information:**
/// - Camera position and file path
/// - Video specifications (resolution, frame rate, bitrate)
/// - Codec information (video/audio)
/// - File metadata (size, duration)
///
/// **Protocols:**
/// - Codable: JSON serialization/deserialization
/// - Equatable: Equality comparison
/// - Identifiable: Unique identification in SwiftUI List/ForEach (id property)
/// - Hashable: Can be used as Set/Dictionary key
///
/// **Usage Example:**
/// ```swift
/// let channel = ChannelInfo(
///     position: .front,
///     filePath: "normal/2025_01_10_09_00_00_F.mp4",
///     width: 1920,
///     height: 1080,
///     frameRate: 30.0,
///     bitrate: 8_000_000,
///     codec: "h264"
/// )
///
/// print(channel.resolutionName)  // "Full HD"
/// print(channel.aspectRatioString)  // "16:9"
/// print(channel.bitrateString ?? "N/A")  // "8.0 Mbps"
/// ```
struct ChannelInfo: Codable, Equatable, Identifiable, Hashable {
    /// @var id
    /// @brief Channel unique identifier (UUID)
    ///
    /// Unique identifier for this channel
    ///
    /// Unique identifier for the channel.
    ///
    /// **UUID (Universally Unique Identifier):**
    /// - Unique identifier composed of 128-bit number
    /// - Format: 8-4-4-4-12 (36 characters including hyphens)
    /// - Example: "550e8400-e29b-41d4-a716-446655440000"
    /// - Collision probability: Nearly 0 (10^-18 level)
    ///
    /// **Identifiable Protocol:**
    /// - Used to distinguish each item in SwiftUI's List and ForEach
    /// - Each ChannelInfo is uniquely identified through the id property
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Display channel list in SwiftUI
    /// List(channels) { channel in
    ///     // channel.id is automatically used as unique identifier
    ///     Text(channel.position.displayName)
    /// }
    /// ```
    let id: UUID

    /// @var position
    /// @brief Camera position/type
    ///
    /// Camera position/type
    ///
    /// The position/type of the camera.
    ///
    /// **CameraPosition enum:**
    /// - front: Front camera
    /// - rear: Rear camera
    /// - left: Left camera
    /// - right: Right camera
    /// - interior: Interior camera
    /// - unknown: Unknown
    ///
    /// **Channel Layout Example:**
    /// ```
    ///         left
    ///          │
    ///     ┌────┼────┐
    ///     │         │
    ///   front     rear
    ///     │         │
    ///     └────┼────┘
    ///          │
    ///        right
    ///
    ///    interior (inside vehicle)
    /// ```
    let position: CameraPosition

    /// @var filePath
    /// @brief Video file path
    ///
    /// File path to the video file for this channel
    ///
    /// File path to the channel's video file.
    ///
    /// **Path Format:**
    /// - Relative or absolute path
    /// - Typically path within blackbox SD card
    ///
    /// **Path Examples:**
    /// ```
    /// "normal/2025_01_10_09_00_00_F.mp4"   (Front, normal recording)
    /// "event/2025_01_10_10_30_15_R.mp4"    (Rear, event)
    /// "/media/sd/normal/2025_01_10_09_00_00_F.mp4"  (Absolute path)
    /// ```
    ///
    /// **Filename Convention:**
    /// - YYYY_MM_DD_HH_MM_SS_Position.mp4
    /// - Position: F(Front), R(Rear), L(Left), Ri(Right), I(Interior)
    let filePath: String

    /// @var width
    /// @brief Video horizontal resolution (pixels)
    ///
    /// Video resolution width in pixels
    ///
    /// Video resolution horizontal pixel count.
    ///
    /// **Common horizontal resolutions:**
    /// - 3840: 4K UHD
    /// - 2560: 2K QHD
    /// - 1920: Full HD
    /// - 1280: HD
    /// - 640: SD
    ///
    /// **Pixel:**
    /// - Smallest unit point composing the screen
    /// - Abbreviation of Picture Element
    /// - More pixels = Sharper video
    let width: Int

    /// @var height
    /// @brief Video vertical resolution (pixels)
    ///
    /// Video resolution height in pixels
    ///
    /// Video resolution vertical pixel count.
    ///
    /// **Common vertical resolutions:**
    /// - 2160: 4K UHD
    /// - 1440: 2K QHD
    /// - 1080: Full HD (1080p)
    /// - 720: HD (720p)
    /// - 480: SD (480p)
    ///
    /// **Meaning of "p":**
    /// - p = Progressive scan
    /// - 1080p: Displays 1080 horizontal lines progressively
    /// - All modern blackboxes use p method
    let height: Int

    /// @var frameRate
    /// @brief Frame rate (fps)
    ///
    /// Frame rate in frames per second
    ///
    /// Frames per second. (fps: frames per second)
    ///
    /// **Frame:**
    /// - Individual still image composing the video
    /// - Showing multiple frames quickly appears like a video
    ///
    /// **Common frame rates:**
    /// - 60.0 fps: Premium blackbox, very smooth video
    /// - 30.0 fps: Standard blackbox (most common)
    /// - 24.0 fps: Cinema standard
    /// - 15.0 fps: Parking mode (low power)
    ///
    /// **Frame rate and video quality:**
    /// - Higher = smoother video
    /// - Better for capturing fast motion (accident moments)
    /// - Proportional to file size (60fps is 2x larger than 30fps)
    ///
    /// **Reason for Double type:**
    /// - Some blackboxes use decimal frame rates like 29.97 fps
    /// - NTSC standard (US, Korea): 29.97 fps
    /// - PAL standard (Europe): 25.0 fps
    let frameRate: Double

    /// @var bitrate
    /// @brief Video bitrate (bps, optional)
    ///
    /// Video bitrate in bits per second (optional)
    ///
    /// Video bitrate. (Unit: bps, bits per second)
    ///
    /// **Bitrate:**
    /// - Amount of data stored per second
    /// - Higher = sharper quality, larger file size
    /// - Lower = compressed quality, smaller file size
    ///
    /// **Unit conversion:**
    /// - 1,000 bps = 1 Kbps (kilobit)
    /// - 1,000,000 bps = 1 Mbps (megabit)
    /// - 8 bits = 1 byte
    /// - 8 Mbps = 1 MB/s (1 megabyte per second)
    ///
    /// **Common bitrates:**
    /// - Full HD (1920×1080):
    ///   - 4,000,000 bps (4 Mbps): Low quality
    ///   - 8,000,000 bps (8 Mbps): Standard ★
    ///   - 12,000,000 bps (12 Mbps): High quality
    ///
    /// - 4K (3840×2160):
    ///   - 16,000,000 bps (16 Mbps): Low quality
    ///   - 24,000,000 bps (24 Mbps): Standard
    ///   - 40,000,000 bps (40 Mbps): High quality
    ///
    /// **Reason for optional:**
    /// - Some file formats may not include bitrate information
    /// - nil on parsing failure
    let bitrate: Int?

    /// @var codec
    /// @brief Video codec (optional)
    ///
    /// Video codec (e.g., "h264", "h265")
    ///
    /// Video codec.
    ///
    /// **Codec:**
    /// - Portmanteau of Coder (compression) + Decoder (decompression)
    /// - Algorithm for compressing/decompressing video data
    /// - File size would be too large without compression
    ///
    /// **Uncompressed Full HD 1 second size:**
    /// - 1920 × 1080 pixels × 3 bytes(RGB) × 30 frames
    /// - = 186 MB/sec
    /// - 1 minute = 11 GB (!!)
    ///
    /// **Common video codecs:**
    ///
    /// 1. h264 (AVC, MPEG-4 Part 10):
    ///    - Most widely used codec
    ///    - Best compatibility (playable on almost all devices)
    ///    - Moderate compression ratio
    ///    - Used by most blackboxes
    ///    - Examples: "h264", "avc1"
    ///
    /// 2. h265 (HEVC, High Efficiency Video Coding):
    ///    - 2x more efficient compression than H.264
    ///    - File size reduced by ~50% at same quality
    ///    - Used by modern blackboxes
    ///    - May not play on some older devices
    ///    - Examples: "h265", "hevc", "hvc1"
    ///
    /// **Compression ratio comparison (same quality):**
    /// ```
    /// Uncompressed: ████████████████ (186 MB/sec)
    /// H.264:        ████ (1 MB/sec, ~1/186 compression)
    /// H.265:        ██ (0.5 MB/sec, ~1/372 compression)
    /// ```
    ///
    /// **Reason for optional:**
    /// - Codec information may fail to parse
    /// - Unknown codec format
    let codec: String?

    /// @var audioCodec
    /// @brief Audio codec (optional)
    ///
    /// Audio codec (e.g., "mp3", "aac") (optional)
    ///
    /// Audio codec.
    ///
    /// **Common audio codecs:**
    ///
    /// 1. AAC (Advanced Audio Coding):
    ///    - Higher quality/efficiency than MP3
    ///    - Optimized for Apple devices
    ///    - Used by modern blackboxes
    ///    - Examples: "aac", "mp4a"
    ///
    /// 2. MP3 (MPEG Audio Layer 3):
    ///    - Most universal codec
    ///    - Best compatibility
    ///    - Used by older blackboxes
    ///    - Examples: "mp3", "mp3a"
    ///
    /// **When audio is absent:**
    /// - Some blackboxes don't record audio
    /// - Audio recording disabled in settings
    /// - audioCodec = nil
    ///
    /// **Reason for optional:**
    /// - Video file without audio
    /// - Codec information parsing failure
    let audioCodec: String?

    /// @var isEnabled
    /// @brief Channel enabled status
    ///
    /// Channel is enabled/active
    ///
    /// Whether the channel is enabled.
    ///
    /// **Enabled/Disabled:**
    /// - true: Channel is enabled (playback, display)
    /// - false: Channel is disabled (hidden, no playback)
    ///
    /// **Usage scenarios:**
    /// - User hides specific channel (e.g., interior camera privacy)
    /// - File corrupted, cannot play
    /// - Selective channel display (show front only, etc.)
    ///
    /// **UI display:**
    /// ```swift
    /// if channel.isEnabled {
    ///     // Play channel
    ///     playerView.isHidden = false
    /// } else {
    ///     // Hide channel
    ///     playerView.isHidden = true
    ///     showDisabledMessage()
    /// }
    /// ```
    let isEnabled: Bool

    /// @var fileSize
    /// @brief File size (bytes)
    ///
    /// File size in bytes
    ///
    /// File size. (Unit: bytes)
    ///
    /// **UInt64 Type:**
    /// - Unsigned Integer 64-bit (unsigned 64-bit integer)
    /// - Range: 0 ~ 18,446,744,073,709,551,615 (approximately 18 exabytes)
    /// - File size cannot be negative, so Unsigned is used
    /// - Can handle large files (64-bit is sufficient)
    ///
    /// **Unit Conversion:**
    /// - 1 KB = 1,024 bytes
    /// - 1 MB = 1,024 KB = 1,048,576 bytes
    /// - 1 GB = 1,024 MB = 1,073,741,824 bytes
    ///
    /// **File Size Examples:**
    /// - Full HD, 30 fps, 8 Mbps, 1 minute:
    ///   - 8 Mbps = 1 MB/second
    ///   - 60 seconds × 1 MB = 60 MB
    ///   - = 62,914,560 bytes (approximately 63 MB)
    ///
    /// - Full HD, 30 fps, 8 Mbps, 1 hour:
    ///   - 60 MB/minute × 60 minutes = 3,600 MB
    ///   - = 3,774,873,600 bytes (approximately 3.6 GB)
    let fileSize: UInt64

    /// @var duration
    /// @brief Video duration (seconds)
    ///
    /// Duration of video in seconds
    ///
    /// Video duration. (Unit: seconds)
    ///
    /// **TimeInterval Type:**
    /// - Typealias for Double
    /// - Standard type for representing time intervals
    /// - Can represent decimal values (e.g., 123.456 seconds)
    ///
    /// **Common Blackbox Recording Durations:**
    /// - 1-minute file: 60.0 seconds
    /// - 3-minute file: 180.0 seconds
    /// - 5-minute file: 300.0 seconds (most common)
    /// - 10-minute file: 600.0 seconds
    ///
    /// **Reasons for Segmented Recording:**
    /// - Minimize damage in case of file corruption
    /// - SD card compatibility (FAT32 has 4GB limit)
    /// - Easier file management
    ///
    /// **Time Conversion:**
    /// ```swift
    /// let seconds = 3665.5  // 1 hour 1 minute 5.5 seconds
    /// let hours = Int(seconds / 3600)  // 1
    /// let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)  // 1
    /// let secs = seconds.truncatingRemainder(dividingBy: 60)  // 5.5
    /// ```
    let duration: TimeInterval

    /// @var timeOffset
    /// @brief Channel time offset (seconds)
    ///
    /// Time offset for this channel in seconds
    ///
    /// Offset to compensate for time differences between channels.
    ///
    /// **What is Time Offset?**
    /// - Compensates for hardware delay between cameras
    /// - Each channel may not start recording at exactly the same time
    /// - Example: Front camera starts 0.05 seconds earlier than rear camera
    ///
    /// **Usage Example:**
    /// ```swift
    /// let frontChannel = ChannelInfo(
    ///     position: .front,
    ///     ...,
    ///     timeOffset: 0.0  // Reference channel
    /// )
    ///
    /// let rearChannel = ChannelInfo(
    ///     position: .rear,
    ///     ...,
    ///     timeOffset: 0.05  // Starts 0.05 seconds late
    /// )
    ///
    /// // When synchronized:
    /// // Front 5.00s frame == Rear 5.05s frame
    /// ```
    ///
    /// **Value Meaning:**
    /// - 0.0: Reference time (usually front camera)
    /// - Positive: This channel starts late (add time)
    /// - Negative: This channel starts early (subtract time)
    let timeOffset: TimeInterval

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
        fileSize: UInt64 = 0,
        duration: TimeInterval = 0,
        timeOffset: TimeInterval = 0.0
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
        self.duration = duration
        self.timeOffset = timeOffset
    }

    // MARK: - Computed Properties

    /// @brief Resolution string (e.g., "1920x1080")
    /// @return "width x height" format
    ///
    /// Resolution as a formatted string (e.g., "1920x1080")
    ///
    /// Returns the resolution as a "width x height" formatted string.
    ///
    /// **Format:**
    /// - "{width}x{height}"
    /// - Examples: "1920x1080", "3840x2160", "1280x720"
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel = ChannelInfo.frontHD
    /// print(channel.resolutionString)  // "1920x1080"
    ///
    /// // UI display
    /// resolutionLabel.text = channel.resolutionString
    /// ```
    var resolutionString: String {
        return "\(width)x\(height)"
    }

    /// @brief Common resolution name (e.g., "Full HD", "4K")
    /// @return Resolution grade name
    ///
    /// Common resolution name (e.g., "Full HD", "4K")
    ///
    /// Returns the common resolution name.
    ///
    /// **Resolution Mapping:**
    /// - 3840 × 2160 → "4K UHD" (Ultra High Definition)
    /// - 2560 × 1440 → "2K QHD" (Quad High Definition)
    /// - 1920 × 1080 → "Full HD"
    /// - 1280 × 720  → "HD"
    /// - 640 × 480   → "SD" (Standard Definition)
    /// - Other       → "1920x1080" (returns resolutionString)
    ///
    /// **switch Pattern Matching:**
    /// - Match two values simultaneously with (width, height) tuple
    /// - case (3840, 2160): Matches only when exactly 3840×2160
    /// - default: All cases not matching above
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel = ChannelInfo(position: .front, ..., width: 1920, height: 1080)
    /// print(channel.resolutionName)  // "Full HD"
    ///
    /// // Display in UI
    /// resolutionLabel.text = channel.resolutionName  // "Full HD"
    /// detailLabel.text = channel.resolutionString    // "1920x1080"
    /// ```
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
            // Unknown resolutions return "1920x1080" format
            return resolutionString
        }
    }

    /// @brief Aspect ratio (decimal)
    /// @return Width/height ratio
    ///
    /// Aspect ratio as a decimal
    ///
    /// Returns the aspect ratio as a decimal number.
    ///
    /// **Aspect Ratio:**
    /// - Ratio of width ÷ height
    /// - Represents the width-to-height ratio of the screen
    ///
    /// **Calculation Formula:**
    /// ```
    /// aspectRatio = width / height
    ///
    /// Examples:
    ///   1920 ÷ 1080 = 1.777... (16:9)
    ///   1280 ÷ 720  = 1.777... (16:9)
    ///   1024 ÷ 768  = 1.333... (4:3)
    ///   2560 ÷ 1080 = 2.370... (21:9)
    /// ```
    ///
    /// **Common Ratios:**
    /// - 1.777 (16:9): Widescreen (standard blackbox, TV)
    /// - 1.333 (4:3): Legacy ratio
    /// - 2.370 (21:9): Ultra-wide
    ///
    /// **Double Casting:**
    /// - width and height are Int type
    /// - Must convert to Double before division for decimal calculation
    /// - Double(width) / Double(height)
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel = ChannelInfo.frontHD
    /// print(channel.aspectRatio)  // 1.7777777777777777
    ///
    /// // Check aspect ratio
    /// if channel.aspectRatio > 2.0 {
    ///     print("Ultra-wide screen")
    /// }
    /// ```
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }

    /// @brief Aspect ratio string (e.g., "16:9")
    /// @return Ratio string
    ///
    /// Aspect ratio as a formatted string (e.g., "16:9")
    ///
    /// Returns the aspect ratio as a human-readable string.
    ///
    /// **Conversion Rules:**
    /// - Close to 16:9 (1.777...) → "16:9"
    /// - Close to 4:3 (1.333...) → "4:3"
    /// - Close to 21:9 (2.333...) → "21:9"
    /// - Other → "1.78:1" (2 decimal places)
    ///
    /// **Approximate Value Comparison:**
    /// - abs(ratio - 16.0/9.0) < 0.01
    /// - abs: Absolute value (convert negative to positive)
    /// - If difference between ratio and 16/9 is less than 0.01, consider "equal"
    /// - Error tolerance: Compensate for floating-point arithmetic errors
    ///
    /// **Calculation Examples:**
    /// ```
    /// 1920 ÷ 1080 = 1.7777...
    /// 16 ÷ 9 = 1.7777...
    /// Difference = |1.7777... - 1.7777...| = 0.0 < 0.01  ✓ → "16:9"
    ///
    /// 1024 ÷ 768 = 1.3333...
    /// 4 ÷ 3 = 1.3333...
    /// Difference = |1.3333... - 1.3333...| = 0.0 < 0.01  ✓ → "4:3"
    ///
    /// 1920 ÷ 1200 = 1.6
    /// 16 ÷ 9 = 1.7777...
    /// Difference = |1.6 - 1.7777...| = 0.1777 > 0.01  ✗ → "1.60:1"
    /// ```
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel1 = ChannelInfo(position: .front, ..., width: 1920, height: 1080)
    /// print(channel1.aspectRatioString)  // "16:9"
    ///
    /// let channel2 = ChannelInfo(position: .front, ..., width: 1024, height: 768)
    /// print(channel2.aspectRatioString)  // "4:3"
    ///
    /// let channel3 = ChannelInfo(position: .front, ..., width: 1920, height: 1200)
    /// print(channel3.aspectRatioString)  // "1.60:1"
    /// ```
    var aspectRatioString: String {
        let ratio = aspectRatio
        // Check for 16:9 (1.777...)
        if abs(ratio - 16.0 / 9.0) < 0.01 {
            return "16:9"
            // Check for 4:3 (1.333...)
        } else if abs(ratio - 4.0 / 3.0) < 0.01 {
            return "4:3"
            // Check for 21:9 (2.333...)
        } else if abs(ratio - 21.0 / 9.0) < 0.01 {
            return "21:9"
            // Other: "1.78:1" format
        } else {
            return String(format: "%.2f:1", ratio)
        }
    }

    /// @brief Frame rate string
    /// @return "XX fps" or "XX.XX fps" format
    ///
    /// Frame rate as formatted string
    ///
    /// Returns the frame rate as a string.
    ///
    /// **Format:**
    /// - Integer frame rate: "30 fps", "60 fps"
    /// - Decimal frame rate: "29.97 fps", "23.98 fps"
    ///
    /// **Integer Check:**
    /// - frameRate == floor(frameRate)
    /// - floor: Rounds down to integer (e.g., floor(30.0) = 30.0)
    /// - 30.0 == floor(30.0) → true (integer)
    /// - 29.97 == floor(29.97) → false (29.97 != 29.0)
    ///
    /// **Format Selection:**
    /// - Integer: "\(Int(frameRate)) fps" → "30 fps"
    /// - Decimal: String(format: "%.2f fps", frameRate) → "29.97 fps"
    ///
    /// **NTSC vs PAL:**
    /// - NTSC (US, Korea): 29.97 fps (exactly 30000/1001)
    /// - PAL (Europe): 25.0 fps
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel1 = ChannelInfo(position: .front, ..., frameRate: 30.0)
    /// print(channel1.frameRateString)  // "30 fps"
    ///
    /// let channel2 = ChannelInfo(position: .front, ..., frameRate: 29.97)
    /// print(channel2.frameRateString)  // "29.97 fps"
    ///
    /// // UI display
    /// fpsLabel.text = channel.frameRateString
    /// ```
    var frameRateString: String {
        // Check for integer frame rate
        if frameRate == floor(frameRate) {
            // Integer: "30 fps"
            return "\(Int(frameRate)) fps"
        } else {
            // Decimal: "29.97 fps"
            return String(format: "%.2f fps", frameRate)
        }
    }

    /// @brief Bitrate string
    /// @return "XX.X Mbps" or "XXX Kbps" format (optional)
    ///
    /// Bitrate as human-readable string
    ///
    /// Returns the bitrate as a human-readable string.
    ///
    /// **Conversion Rules:**
    /// - >= 1,000,000 bps → Mbps (megabits)
    /// - < 1,000,000 bps → Kbps (kilobits)
    ///
    /// **Unit Conversion:**
    /// ```
    /// 1 Mbps = 1,000,000 bps
    /// 1 Kbps = 1,000 bps
    ///
    /// Examples:
    ///   8,000,000 bps = 8.0 Mbps
    ///   4,500,000 bps = 4.5 Mbps
    ///   750,000 bps = 750 Kbps
    /// ```
    ///
    /// **Format:**
    /// - Mbps: 1 decimal place (e.g., "8.0 Mbps")
    /// - Kbps: Integer (e.g., "750 Kbps")
    ///
    /// **Optional Return:**
    /// - Returns nil if bitrate is nil
    /// - Uses guard let for optional binding
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel1 = ChannelInfo(position: .front, ..., bitrate: 8_000_000)
    /// print(channel1.bitrateString ?? "N/A")  // "8.0 Mbps"
    ///
    /// let channel2 = ChannelInfo(position: .front, ..., bitrate: 750_000)
    /// print(channel2.bitrateString ?? "N/A")  // "750 Kbps"
    ///
    /// let channel3 = ChannelInfo(position: .front, ..., bitrate: nil)
    /// print(channel3.bitrateString ?? "N/A")  // "N/A"
    ///
    /// // UI display
    /// bitrateLabel.text = channel.bitrateString ?? "Unknown"
    /// ```
    var bitrateString: String? {
        // Return nil if bitrate is nil
        guard let bitrate = bitrate else { return nil }

        // Convert to Mbps
        let mbps = Double(bitrate) / 1_000_000

        // >= 1 Mbps: Display in Mbps
        if mbps >= 1.0 {
            return String(format: "%.1f Mbps", mbps)
            // < 1 Mbps: Display in Kbps
        } else {
            let kbps = Double(bitrate) / 1000
            return String(format: "%.0f Kbps", kbps)
        }
    }

    /// @brief File size string
    /// @return "XXX MB" or "X.X GB" format
    ///
    /// File size as human-readable string
    ///
    /// Returns the file size as a human-readable string.
    ///
    /// **ByteCountFormatter:**
    /// - Foundation's standard file size formatter
    /// - Automatically selects appropriate unit (Bytes, KB, MB, GB)
    /// - Displays in locale-appropriate format
    ///
    /// **countStyle:**
    /// - .file: File size format (1024-based, binary)
    ///   - 1 KB = 1,024 bytes
    ///   - 1 MB = 1,024 KB
    ///   - 1 GB = 1,024 MB
    ///
    /// - .memory: Memory format (same as .file, clearer name)
    ///
    /// - .decimal: Decimal format (1000-based)
    ///   - 1 KB = 1,000 bytes
    ///   - 1 MB = 1,000 KB
    ///
    /// **Format Examples:**
    /// ```
    /// 1,024 bytes       → "1 KB"
    /// 1,048,576 bytes   → "1 MB"
    /// 104,857,600 bytes → "100 MB"
    /// 1,073,741,824 bytes → "1 GB"
    /// ```
    ///
    /// **Int64 Casting:**
    /// - ByteCountFormatter.string(fromByteCount:) takes Int64 parameter
    /// - fileSize is UInt64
    /// - Must convert with Int64(fileSize)
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel = ChannelInfo(position: .front, ..., fileSize: 104_857_600)
    /// print(channel.fileSizeString)  // "100 MB"
    ///
    /// // UI display
    /// fileSizeLabel.text = "Size: \(channel.fileSizeString)"
    /// ```
    var fileSizeString: String {
        // Create ByteCountFormatter
        let formatter = ByteCountFormatter()
        // File size format (1024-based)
        formatter.countStyle = .file
        // Convert UInt64 to Int64 and format
        return formatter.string(fromByteCount: Int64(fileSize))
    }

    /// @brief Extract filename from file path
    /// @return Filename (excluding path)
    ///
    /// Filename extracted from path
    ///
    /// Extracts only the filename from the file path.
    ///
    /// **Path vs Filename:**
    /// ```
    /// Path:     "normal/2025_01_10_09_00_00_F.mp4"
    ///                    ↓ lastPathComponent
    /// Filename: "2025_01_10_09_00_00_F.mp4"
    /// ```
    ///
    /// **NSString.lastPathComponent:**
    /// - Returns the last component of the path (filename)
    /// - String after directory separator (/)
    /// - Used by casting Swift String to NSString
    ///
    /// **Examples:**
    /// ```
    /// "normal/2025_01_10_09_00_00_F.mp4"       → "2025_01_10_09_00_00_F.mp4"
    /// "/media/sd/event/2025_01_10_10_30_15_R.mp4" → "2025_01_10_10_30_15_R.mp4"
    /// "video.mp4"                              → "video.mp4"
    /// ```
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel = ChannelInfo(
    ///     position: .front,
    ///     filePath: "normal/2025_01_10_09_00_00_F.mp4",
    ///     ...
    /// )
    /// print(channel.filename)  // "2025_01_10_09_00_00_F.mp4"
    ///
    /// // UI display
    /// filenameLabel.text = channel.filename
    /// ```
    var filename: String {
        return (filePath as NSString).lastPathComponent
    }

    /// @brief Check for high-resolution channel (>= 1080p)
    /// @return True if 1080p or higher
    ///
    /// Check if this is a high-resolution channel (>= 1080p)
    ///
    /// Checks if the channel is high-resolution (1080p or higher).
    ///
    /// **High-Resolution Criteria:**
    /// - height >= 1080 (vertical pixels 1080 or more)
    /// - Full HD (1920×1080) or higher
    ///
    /// **Resolution Classification:**
    /// ```
    /// High-resolution (true):
    ///   - 4K UHD (3840×2160)     height: 2160 ✓
    ///   - 2K QHD (2560×1440)     height: 1440 ✓
    ///   - Full HD (1920×1080)    height: 1080 ✓
    ///
    /// Low-resolution (false):
    ///   - HD (1280×720)          height: 720  ✗
    ///   - SD (640×480)           height: 480  ✗
    /// ```
    ///
    /// **Usage:**
    /// - UI layout adjustment (high-resolution uses larger screen)
    /// - Performance optimization (high-resolution uses more resources)
    /// - Quality indication (display high-resolution badge)
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel = ChannelInfo.frontHD  // 1920×1080
    /// if channel.isHighResolution {
    ///     print("High-resolution channel")
    ///     // Use high-resolution UI layout
    ///     playerView.frame = largeFrame
    /// } else {
    ///     print("Low-resolution channel")
    ///     // Use low-resolution UI layout
    ///     playerView.frame = smallFrame
    /// }
    /// ```
    var isHighResolution: Bool {
        return height >= 1080
    }

    /// @brief Check audio availability
    /// @return True if audio is present
    ///
    /// Check if audio is available
    ///
    /// Checks if audio is present.
    ///
    /// **Check Logic:**
    /// - audioCodec != nil: Audio present if audio codec exists
    /// - audioCodec == nil: No audio if audio codec is absent
    ///
    /// **Cases Without Audio:**
    /// - Audio recording disabled in blackbox settings
    /// - No audio hardware (budget blackbox)
    /// - File corruption or codec parsing failure
    ///
    /// **Usage:**
    /// - Show/hide audio control UI
    /// - Enable/disable volume adjustment buttons
    /// - Display no-audio message
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel = ChannelInfo.frontHD
    /// if channel.hasAudio {
    ///     print("Audio present: \(channel.audioCodec ?? "unknown")")
    ///     // Show audio controls
    ///     volumeSlider.isHidden = false
    ///     muteButton.isHidden = false
    /// } else {
    ///     print("No audio")
    ///     // Hide audio controls
    ///     volumeSlider.isHidden = true
    ///     muteButton.isHidden = true
    ///     showNoAudioMessage()
    /// }
    /// ```
    var hasAudio: Bool {
        return audioCodec != nil
    }

    // MARK: - Validation

    /// @brief Validate required properties
    /// @return True if all required properties are valid
    ///
    /// Validate that all required properties are valid
    ///
    /// Validates that all required properties are valid.
    ///
    /// **Validation Conditions:**
    /// 1. width > 0: Horizontal resolution is positive
    /// 2. height > 0: Vertical resolution is positive
    /// 3. frameRate > 0: Frame rate is positive
    /// 4. !filePath.isEmpty: File path is not empty
    ///
    /// **Logical AND (&&) Operation:**
    /// - Final result is true only if all conditions are true
    /// - Final result is false if any condition is false
    ///
    /// **Validation Examples:**
    /// ```
    /// Valid channel:
    ///   width: 1920 > 0       ✓
    ///   height: 1080 > 0      ✓
    ///   frameRate: 30.0 > 0   ✓
    ///   filePath: "normal/2025_01_10_09_00_00_F.mp4"  ✓
    ///   → isValid = true
    ///
    /// Invalid channel:
    ///   width: 0              ✗ (0 is invalid)
    ///   → isValid = false
    ///
    /// Empty path:
    ///   filePath: ""          ✗ (empty)
    ///   → isValid = false
    /// ```
    ///
    /// **Usage:**
    /// - Data integrity verification
    /// - Filter out invalid data
    /// - Error handling
    ///
    /// **Usage Example:**
    /// ```swift
    /// let channel = ChannelInfo(
    ///     position: .front,
    ///     filePath: "normal/2025_01_10_09_00_00_F.mp4",
    ///     width: 1920,
    ///     height: 1080,
    ///     frameRate: 30.0
    /// )
    ///
    /// if channel.isValid {
    ///     print("Valid channel")
    ///     // Play channel
    ///     playChannel(channel)
    /// } else {
    ///     print("Invalid channel data")
    ///     // Error handling
    ///     showError("Channel data is invalid")
    /// }
    ///
    /// // Filter only valid channels
    /// let validChannels = channels.filter { $0.isValid }
    /// ```
    var isValid: Bool {
        return width > 0 &&
            height > 0 &&
            frameRate > 0 &&
            !filePath.isEmpty
    }
}

// MARK: - Sample Data

/*
 ───────────────────────────────────────────────────────────────────────────────
 Sample Data - Sample Channel Data
 ───────────────────────────────────────────────────────────────────────────────

 Sample data for testing, SwiftUI previews, and UI verification during development.

 【Sample Channel Configuration】

 1. frontHD: Front camera (Full HD, 1920×1080, 30fps, 8 Mbps)
 - Most common configuration
 - Audio included (MP3)

 2. rearHD: Rear camera (HD, 1280×720, 30fps, 4 Mbps)
 - Lower resolution than front (typical)
 - No audio

 3. leftHD: Left camera (HD, 1280×720, 30fps, 4 Mbps)
 - For 4+ channel blackbox

 4. rightHD: Right camera (HD, 1280×720, 30fps, 4 Mbps)
 - For 4+ channel blackbox

 5. interiorHD: Interior camera (HD, 1280×720, 30fps, 4 Mbps)
 - For taxi, ride-sharing vehicles

 【Real Blackbox Resolution Configuration Examples】

 2-channel standard:
 - Front: Full HD (1920×1080)
 - Rear: HD (1280×720)

 2-channel premium:
 - Front: 4K (3840×2160)
 - Rear: Full HD (1920×1080)

 4-channel:
 - Front: Full HD (1920×1080)
 - Rear/Left/Right: HD (1280×720)

 【Usage Examples】

 SwiftUI Preview:
 ```swift
 struct ChannelView_Previews: PreviewProvider {
 static var previews: some View {
 Group {
 ChannelView(channel: .frontHD)
 .previewDisplayName("Front Camera")

 ChannelView(channel: .rearHD)
 .previewDisplayName("Rear Camera")
 }
 }
 }
 ```

 Unit Test:
 ```swift
 func testChannelValidation() {
 XCTAssertTrue(ChannelInfo.frontHD.isValid)
 XCTAssertTrue(ChannelInfo.frontHD.isHighResolution)
 XCTAssertTrue(ChannelInfo.frontHD.hasAudio)
 }

 func testResolutionNames() {
 XCTAssertEqual(ChannelInfo.frontHD.resolutionName, "Full HD")
 XCTAssertEqual(ChannelInfo.rearHD.resolutionName, "HD")
 }
 ```

 ───────────────────────────────────────────────────────────────────────────────
 */

extension ChannelInfo {
    /// Sample front camera (Full HD)
    ///
    /// Front camera sample. (Full HD)
    ///
    /// **Specifications:**
    /// - Position: Front
    /// - Resolution: 1920×1080 (Full HD)
    /// - Frame Rate: 30 fps
    /// - Bitrate: 8 Mbps
    /// - Codec: H.264
    /// - Audio: MP3
    /// - File Size: 100 MB
    ///
    /// **Typical Front Camera Settings:**
    /// - Highest resolution (Full HD or 4K)
    /// - Audio recording enabled
    /// - High bitrate for clear quality
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
    ///
    /// Rear camera sample. (HD)
    ///
    /// **Specifications:**
    /// - Position: Rear
    /// - Resolution: 1280×720 (HD)
    /// - Frame Rate: 30 fps
    /// - Bitrate: 4 Mbps
    /// - Codec: H.264
    /// - Audio: None
    /// - File Size: 50 MB
    ///
    /// **Typical Rear Camera Settings:**
    /// - Lower resolution than front (cost savings)
    /// - No audio (redundant recording unnecessary)
    /// - 50% of front bitrate
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
    ///
    /// Left camera sample. (HD)
    ///
    /// **Specifications:**
    /// - Position: Left
    /// - Resolution: 1280×720 (HD)
    /// - Used in 4+ channel blackbox
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
    ///
    /// Right camera sample. (HD)
    ///
    /// **Specifications:**
    /// - Position: Right
    /// - Resolution: 1280×720 (HD)
    /// - Used in 4+ channel blackbox
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
    ///
    /// Interior camera sample. (HD)
    ///
    /// **Specifications:**
    /// - Position: Interior
    /// - Resolution: 1280×720 (HD)
    /// - For taxi, ride-sharing vehicles
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
    ///
    /// Array of all sample channels.
    ///
    /// **Included Channels:**
    /// - frontHD: Front Full HD
    /// - rearHD: Rear HD
    /// - leftHD: Left HD
    /// - rightHD: Right HD
    /// - interiorHD: Interior HD
    ///
    /// **Usage Example:**
    /// ```swift
    /// // Display all channels in SwiftUI List
    /// List(ChannelInfo.allSampleChannels) { channel in
    ///     VStack(alignment: .leading) {
    ///         Text(channel.position.displayName)
    ///         Text(channel.resolutionName)
    ///     }
    /// }
    ///
    /// // 5-channel blackbox simulation
    /// let multiChannelPlayer = MultiChannelPlayer(
    ///     channels: ChannelInfo.allSampleChannels
    /// )
    /// ```
    static let allSampleChannels: [ChannelInfo] = [
        frontHD,
        rearHD,
        leftHD,
        rightHD,
        interiorHD
    ]
}
